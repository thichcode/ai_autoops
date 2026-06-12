#!/bin/bash
set -euo pipefail; ENV="$1"; NODE="${CURRENT_NODE:-${MINIO_NODES[0]}}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "VERIFY" "Verifying MinIO on $NODE"
ADDR="${NODE%:*}"; PORT="${NODE#*:}"; CPORT="$MINIO_CONSOLE_PORT"
ssh_run "$ADDR" "systemctl start $MINIO_SERVICE" || true; sleep 15
ssh_run "$ADDR" "systemctl is-active $MINIO_SERVICE" | grep -q active || { log_error "Service not active"; exit 1; }
curl -s "http://${ADDR}:${PORT}/minio/health/live" 2>/dev/null | grep -q 'ok' && log_info "S3 API OK" || log_warn "S3 API not ready"
curl -s "http://${ADDR}:${CPORT}" -o /dev/null -w '%{http_code}' 2>/dev/null | grep -q 200 && log_info "Console OK" || log_warn "Console not ready"
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "VERIFY" "Node verified: $NODE"
