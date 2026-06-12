#!/bin/bash
set -euo pipefail; ENV="$1"; NODE="${CURRENT_NODE:-${MINIO_NODES[0]}}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "ROLLBACK" "Rolling back MinIO on $NODE"
ADDR="${NODE%:*}"; ssh_run "$ADDR" "systemctl stop $MINIO_SERVICE" || true
# Restore previous binary
PREV_VERSION=$(ssh_run "$ADDR" "ls /usr/local/bin/minio.bak 2>/dev/null" || true)
[[ -n "$PREV_VERSION" ]] && ssh_run "$ADDR" "cp /usr/local/bin/minio.bak /usr/local/bin/minio" || log_warn "No previous binary to restore"
ssh_run "$ADDR" "systemctl start $MINIO_SERVICE" || true
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "ROLLBACK" "MinIO rollback completed"
