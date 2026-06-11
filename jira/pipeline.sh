#!/bin/bash
# Jira pipeline orchestrator
# Usage: ./pipeline.sh --action patch --env prod
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

CURRENT_STAGE=""
ROLLBACK_TRIGGERED=false
declare -a COMPLETED_STAGES=()

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 && "$ROLLBACK_TRIGGERED" == false ]]; then
        ROLLBACK_TRIGGERED=true
        log_warn "Pipeline failed at stage: $CURRENT_STAGE. Triggering rollback..."
        notify_failure "Jira pipeline failed at $CURRENT_STAGE on $ENV" "See audit log for details"
        run_stage "rollback"
    fi
    audit_record "PIPELINE_END" "$([ $exit_code -eq 0 ] && echo SUCCESS || echo FAILURE)" \
        "Stages completed: ${COMPLETED_STAGES[*]}"
}
trap cleanup EXIT

run_stage() {
    local stage="$1"
    CURRENT_STAGE="$stage"
    local stage_script="$SCRIPT_DIR/stages/${stage}.sh"
    if [[ ! -f "$stage_script" ]]; then
        stage_script="$PROJECT_ROOT/shared/templates/${stage}.sh"
    fi
    if [[ ! -f "$stage_script" ]]; then
        log_error "Stage script not found: $stage"
        return 1
    fi
    audit_started "STAGE_$stage" "Starting stage: $stage"
    log_info "=== Stage: $stage ==="
    if bash "$stage_script" "$ENV"; then
        audit_success "STAGE_$stage" "Completed stage: $stage"
        COMPLETED_STAGES+=("$stage")
    else
        audit_failure "STAGE_$stage" "Failed stage: $stage"
        return 1
    fi
}

# Main pipeline
audit_started "PIPELINE" "Jira $ACTION pipeline starting on $ENV"
notify "Jira pipeline started" "Action: $ACTION, Environment: $ENV"

run_stage "precheck"
run_stage "backup"
run_stage "restore-test"

if [[ "$ACTION" == "patch" ]]; then
    for node in "${JIRA_NODES[@]}"; do
        log_info "Processing node: $node"
        export CURRENT_NODE="$node"
        run_stage "drain"
        run_stage "maint"
        run_stage "deploy"
        run_stage "verify" || {
            log_error "Verification failed on $node, triggering rollback"
            run_stage "rollback"
            exit 1
        }
        log_info "Node $node completed successfully"
    done
elif [[ "$ACTION" == "restore" ]]; then
    run_stage "maint"
    run_stage "deploy"
    run_stage "verify"
fi

notify_success "Jira pipeline completed" "Action: $ACTION, Environment: $ENV"
log_info "Pipeline completed successfully"
