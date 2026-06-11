#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "DRAIN" "Disabling Zabbix proxies"
for px in "${ZABBIX_PROXIES[@]}"; do
    ssh_run "$ZABBIX_SERVER" "zabbix_server -R proxy_config_drop:$px 2>/dev/null" || true
    log_info "Dropped proxy: $px"
done
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 0}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$ZABBIX_WEB_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; sleep 10; audit_success "DRAIN" "Zabbix drained"
