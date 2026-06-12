#!/bin/bash
set -euo pipefail; SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh" "$PROJECT_ROOT/shared/lib/notify.sh"
ACTION="${1:-patch}"; ENV="${2:-prod}"; source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
CURRENT_STAGE=""; ROLLBACK_TRIGGERED=false; declare -a COMPLETED_STAGES=()
cleanup() { local rc=$?; if [[ $rc -ne 0 && "$ROLLBACK_TRIGGERED" == false ]]; then ROLLBACK_TRIGGERED=true; notify_failure "GitLab Runner pipeline failed at $CURRENT_STAGE" ""; run_stage "rollback"; fi; audit_record "PIPELINE_END" "$([ $rc -eq 0 ] && echo SUCCESS || echo FAILURE)" "Stages: ${COMPLETED_STAGES[*]}"; }; trap cleanup EXIT
run_stage() { CURRENT_STAGE="$1"; local s="$SCRIPT_DIR/stages/${1}.sh"; [[ -f "$s" ]] || s="$PROJECT_ROOT/shared/templates/${1}.sh"; [[ -f "$s" ]] || { log_error "Stage not found: $1"; return 1; }; audit_started "STAGE_$1" "Starting: $1"; log_info "=== Stage: $1 ==="; bash "$s" "$ENV" && { audit_success "STAGE_$1" "Completed"; COMPLETED_STAGES+=("$1"); } || { audit_failure "STAGE_$1" "Failed"; return 1; }; }
audit_started "PIPELINE" "GitLab Runner $ACTION on $ENV"; notify "GitLab Runner pipeline started"
run_stage "precheck" && run_stage "backup" && run_stage "restore-test"
if [[ "$ACTION" == "patch" ]]; then
    for node in "${RUNNER_LINUX_NODES[@]}"; do export CURRENT_NODE="$node"; run_stage "drain" && run_stage "maint" && run_stage "deploy" && run_stage "verify" || { run_stage "rollback"; exit 1; }; done
    for node in "${RUNNER_WIN_NODES[@]}"; do export CURRENT_NODE="$node"; run_stage "drain" && run_stage "maint" && run_stage "deploy" && run_stage "verify" || { run_stage "rollback"; exit 1; }; done
fi
notify_success "GitLab Runner pipeline completed"
