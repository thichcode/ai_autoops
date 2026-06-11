#!/bin/bash
# rollback.sh — Rollback Jira node to previous version

set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/rollback.sh"

NODE="${CURRENT_NODE:-${JIRA_NODES[0]}}"
audit_started "ROLLBACK" "Rolling back Jira on $NODE"

log_info "Stopping Jira service on $NODE"
ssh_run "$NODE" "systemctl stop $JIRA_SERVICE" || true

BACKUP_DIR="${BACKUP_BASE}/jira-${ENV}-backup"
ssh_run "$NODE" "if [[ -d $BACKUP_DIR ]]; then cp -a $BACKUP_DIR/* $JIRA_INSTALL_DIR/; fi"
log_info "Restored files from $BACKUP_DIR"

ssh_run "$NODE" "systemctl start $JIRA_SERVICE"
log_info "Jira service restarted on $NODE"

if [[ -n "$NGINX_PLUS_API" ]]; then
    curl -s -X PATCH -d '{"weight": 1, "drain": false}' \
        "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" \
        --user "$NGINX_PLUS_API_USER:$NGINX_PLUS_API_PASS" || true
fi

audit_success "ROLLBACK" "Rollback completed on $NODE"
notify_warning "Jira rollback completed" "Node $NODE rolled back to previous version"
