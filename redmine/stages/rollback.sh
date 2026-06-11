#!/bin/bash
set -euo pipefail
ENV="$1"; NODE="${CURRENT_NODE:-${REDMINE_NODES[0]}}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "ROLLBACK" "Rolling back Redmine on $NODE"
ssh_run "$NODE" "systemctl stop $REDMINE_SERVICE" || true
ssh_run "$NODE" "[[ -d ${BACKUP_BASE}/redmine-previous ]] && cp -a ${BACKUP_BASE}/redmine-previous/* $REDMINE_HOME/" || true
ssh_run "$NODE" "systemctl start $REDMINE_SERVICE" || true
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "ROLLBACK" "Rollback completed on $NODE"
