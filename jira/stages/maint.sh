#!/bin/bash
# maint.sh — Enable maintenance mode / stop Jira service

set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

NODE="${CURRENT_NODE:?CURRENT_NODE not set}"
audit_started "MAINT" "Maintenance mode on $NODE"

if [[ -n "$MAINTENANCE_PAGE" && -f "$MAINTENANCE_PAGE" ]]; then
    log_info "Maintenance page already exists: $MAINTENANCE_PAGE"
fi

log_info "Stopping Jira service on $NODE"
ssh_run "$NODE" "systemctl stop $JIRA_SERVICE" || {
    log_error "Failed to stop Jira service on $NODE"
    return 1
}
sleep 5
if ssh_run "$NODE" "systemctl is-active $JIRA_SERVICE 2>/dev/null" | grep -q "inactive"; then
    log_info "Jira service stopped on $NODE"
else
    log_error "Jira service still active on $NODE"
    return 1
fi

audit_success "MAINT" "Service stopped on $NODE"
