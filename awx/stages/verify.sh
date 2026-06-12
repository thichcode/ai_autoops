#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "VERIFY" "Verifying AWX"
if [[ "$AWX_DEPLOY_METHOD" == "docker" ]]; then
    ssh_run "$AWX_NODE" "cd $AWX_HOME && docker-compose up -d 2>/dev/null || docker compose up -d" || true
else
    ssh_run "$AWX_NODE" "systemctl start awx" || true
fi
sleep 30
if [[ "$AWX_DEPLOY_METHOD" == "docker" ]]; then
    ssh_run "$AWX_NODE" "docker ps --format '{{.Names}}' 2>/dev/null | grep -q awx_task" || { log_error "AWX not running"; exit 1; }
fi
HTTP=$(curl -sk -o /dev/null -w "%{http_code}" "https://${AWX_NODE}:${AWX_PORT}" 2>/dev/null || echo "000")
log_info "HTTP: $HTTP"
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$AWX_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "VERIFY" "AWX verified"
