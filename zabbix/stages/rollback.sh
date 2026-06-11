#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "ROLLBACK" "Rolling back Zabbix"
ssh_run "$ZABBIX_SERVER" "systemctl stop $ZABBIX_SERVICE_SERVER $ZABBIX_SERVICE_AGENT" || true
# Rollback via yum history or package revert
ssh_run "$ZABBIX_SERVER" "yum history undo last 2>/dev/null || apt-get install --reinstall zabbix-server-pgsql=$ZABBIX_VERSION 2>/dev/null" || true
ssh_run "$ZABBIX_SERVER" "systemctl start $ZABBIX_SERVICE_SERVER $ZABBIX_SERVICE_AGENT" || true
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$ZABBIX_WEB_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "ROLLBACK" "Zabbix rollback completed"
