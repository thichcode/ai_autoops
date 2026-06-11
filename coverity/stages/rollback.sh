#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

audit_started "ROLLBACK" "Rolling back Coverity on $COV_HOST"
LATEST_BACKUP=$(ssh_run "$COV_HOST" "ls -td ${COV_INSTALL_DIR}.* 2>/dev/null | head -1" 2>/dev/null)
if [[ -n "$LATEST_BACKUP" ]]; then
    ssh_run "$COV_HOST" "systemctl stop $COV_SERVICE; rm -rf $COV_INSTALL_DIR; cp -a $LATEST_BACKUP $COV_INSTALL_DIR; systemctl start $COV_SERVICE"
    log_info "Rolled back Coverity from $LATEST_BACKUP"
    audit_success "ROLLBACK" "Coverity restored from $LATEST_BACKUP"
else
    log_error "No backup found for rollback"
    audit_failure "ROLLBACK" "No backup available"
fi
