#!/bin/bash
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
cleanup() {
    local rc=$?
    if [[ $rc -ne 0 && "$ROLLBACK_TRIGGERED" == false ]]; then
        ROLLBACK_TRIGGERED=true; run_stage "rollback"
    fi
    audit_record "PIPELINE_END" "$([ $rc -eq 0 ] && echo SUCCESS || echo FAILURE)" ""
}
trap cleanup EXIT

run_stage() {
    CURRENT_STAGE="$1"; audit_started "STAGE_$1" "Starting: $1"
    log_info "=== Stage: $1 ==="
    bash "$SCRIPT_DIR/stages/${1}.sh" "$ENV" && audit_success "STAGE_$1" "OK" || { audit_failure "STAGE_$1" "FAIL"; return 1; }
}

audit_started "PIPELINE" "Coverity $ACTION pipeline on $ENV"
run_stage "precheck" && run_stage "backup" && run_stage "restore-test" && run_stage "deploy" && run_stage "verify" || { run_stage "rollback"; exit 1; }
notify_success "Coverity pipeline done" "$ACTION on $ENV"
