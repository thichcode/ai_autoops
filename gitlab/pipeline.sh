#!/bin/bash
# GitLab pipeline orchestrator (multi-node)
# Rolling update: app nodes one by one, DB/Redis/NFS verified before deploy
# Stages: precheck -> backup -> restore-test -> drain -> maint -> deploy -> verify -> [commit|rollback] -> audit
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/notify.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

ACTION="${1:-patch}"
ENV="${2:-prod}"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"

CURRENT_STAGE=""; ROLLBACK_TRIGGERED=false
declare -a COMPLETED_STAGES=()

cleanup() {
    local rc=$?
    if [[ $rc -ne 0 && "$ROLLBACK_TRIGGERED" == false ]]; then
        ROLLBACK_TRIGGERED=true; log_warn "Pipeline failed at: $CURRENT_STAGE. Rolling back..."
        run_stage "rollback"
    fi
    audit_record "PIPELINE_END" "$([ $rc -eq 0 ] && echo SUCCESS || echo FAILURE)" "Stages: ${COMPLETED_STAGES[*]}"
}
trap cleanup EXIT

run_stage() {
    CURRENT_STAGE="$1"; audit_started "STAGE_$1" "Starting: $1"
    log_info "=== Stage: $1 ==="
    if bash "$SCRIPT_DIR/stages/${1}.sh" "$ENV"; then
        audit_success "STAGE_$1" "Completed"; COMPLETED_STAGES+=("$1")
    else
        audit_failure "STAGE_$1" "Failed"; return 1
    fi
}

audit_started "PIPELINE" "GitLab $ACTION pipeline on $ENV"
notify "GitLab pipeline started" "Action: $ACTION, Env: $ENV"

run_stage "precheck"
run_stage "backup"
run_stage "restore-test"

if [[ "$ACTION" == "patch" ]]; then
    for node in "${GITLAB_APP_NODES[@]}"; do
        log_info "Processing app node: $node"
        export CURRENT_NODE="$node"
        run_stage "drain"
        run_stage "maint"
        run_stage "deploy"
        run_stage "verify" || {
            log_error "Verification failed on $node, triggering rollback"
            run_stage "rollback"
            exit 1
        }
    done
elif [[ "$ACTION" == "restore" ]]; then
    run_stage "maint"
    run_stage "deploy"
    run_stage "verify"
fi

notify_success "GitLab pipeline completed" "Action: $ACTION, Env: $ENV"
