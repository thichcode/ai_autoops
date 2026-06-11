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

audit_started "ROLLBACK" "Rolling back BlackDuck on $BD_HOST"
LATEST_BACKUP=$(ssh_run "$BD_HOST" "ls -td ${BD_INSTALL_DIR}.* 2>/dev/null | head -1" 2>/dev/null)
if [[ -n "$LATEST_BACKUP" ]]; then
    ssh_run "$BD_HOST" "systemctl stop $BD_SERVICE; rm -rf $BD_INSTALL_DIR; cp -a $LATEST_BACKUP $BD_INSTALL_DIR; systemctl start $BD_SERVICE"
    log_info "Rolled back BlackDuck from $LATEST_BACKUP"
    audit_success "ROLLBACK" "BlackDuck restored from $LATEST_BACKUP"
else
    log_error "No backup found for rollback"
    audit_failure "ROLLBACK" "No backup available"
fi
