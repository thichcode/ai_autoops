#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/utils.sh"
check_rbac "minio-admins" || exit 1
for node in "${MINIO_NODES[@]}"; do
    addr="${node%:*}"
    ping -c 2 "$addr" &>/dev/null && log_info "Node OK: $addr" || { log_error "Node unreachable: $addr"; exit 1; }
done
FIRST="${MINIO_NODES[0]%;*}"
ADDR="${FIRST%:*}"; PORT="${FIRST#*:}"
curl -s "http://${ADDR}:${MINIO_CONSOLE_PORT}" -o /dev/null -w '%{http_code}' 2>/dev/null | grep -q 200 && log_info "Console UI OK" || log_warn "Console not accessible"
log_info "All pre-checks passed"
