#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "VERIFY" "Verifying Harbor"
ssh_run "$HARBOR_NODE" "cd $HARBOR_HOME && docker-compose up -d 2>/dev/null || docker compose up -d" || true; sleep 30
ssh_run "$HARBOR_NODE" "docker ps --format '{{.Names}}' 2>/dev/null | grep -q harbor-core" || { log_error "Harbor core not running"; exit 1; }
curl -sk "https://${HARBOR_NODE}:${HARBOR_PORT}/api/v2.0/ping" &>/dev/null && log_info "API OK" || log_warn "API not responding"
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$HARBOR_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "VERIFY" "Harbor verified"
