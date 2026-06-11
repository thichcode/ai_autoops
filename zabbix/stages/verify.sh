#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "VERIFY" "Verifying Zabbix"
for srv in "$ZABBIX_SERVICE_SERVER" "$ZABBIX_SERVICE_AGENT"; do
    ssh_run "$ZABBIX_SERVER" "systemctl start $srv" || true
done
for px in "${ZABBIX_PROXIES[@]}"; do
    ssh_run "$px" "systemctl start $ZABBIX_SERVICE_PROXY" || true
done
sleep 30
ssh_run "$ZABBIX_SERVER" "systemctl is-active $ZABBIX_SERVICE_SERVER" | grep -q active || { log_error "Server not active"; exit 1; }
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://${ZABBIX_WEB_NODE}:${ZABBIX_WEB_PORT}" 2>/dev/null || echo "000")
log_info "HTTP: $HTTP"
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$ZABBIX_WEB_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "VERIFY" "Zabbix verified"
