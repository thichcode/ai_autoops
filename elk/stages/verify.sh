#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "VERIFY" "Verifying ELK stack"
for node in "${ES_NODES[@]}"; do ssh_run "$node" "systemctl start $ES_SERVICE" || true; done
sleep 30
ssh_run "${ES_NODES[0]}" "systemctl is-active $ES_SERVICE" | grep -q active || { log_error "ES not active"; exit 1; }
ssh_run "$KB_NODE" "systemctl start $KB_SERVICE" || true; sleep 15
ssh_run "$LS_NODE" "systemctl start $LS_SERVICE" || true; sleep 10
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://${KB_NODE}:${KB_PORT}" 2>/dev/null || echo "000"); log_info "Kibana HTTP: $HTTP"
HEALTH=$(curl -s "http://${ES_NODES[0]}:${ES_PORT}/_cluster/health" 2>/dev/null | grep -o '"status":"[^"]*"' || echo "unknown"); log_info "ES health: $HEALTH"
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$KB_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "VERIFY" "ELK verified"
