#!/bin/bash
set -euo pipefail
ENV="$1"; NODE="${CURRENT_NODE:-${CONF_NODES[0]}}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

audit_started "ROLLBACK" "Rolling back Confluence on $NODE"
ssh_run "$NODE" "systemctl stop $CONF_SERVICE" || true
BACKUP_DIR="${BACKUP_BASE}/confluence-${ENV}-backup"
ssh_run "$NODE" "[[ -d $BACKUP_DIR ]] && cp -a $BACKUP_DIR/* $CONF_INSTALL_DIR/" || true
ssh_run "$NODE" "systemctl start $CONF_SERVICE" || true
local NETRC=$(mktemp)
echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1, "drain": false}' \
    "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"
audit_success "ROLLBACK" "Rollback completed on $NODE"
