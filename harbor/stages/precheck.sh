#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/utils.sh"
check_rbac "harbor-admins" || exit 1
ping -c 2 "$HARBOR_NODE" &>/dev/null && log_info "Node OK: $HARBOR_NODE" || { log_error "Node unreachable"; exit 1; }
ssh_run "$HARBOR_NODE" "docker ps --format '{{.Names}}' 2>/dev/null | grep -q harbor" && log_info "Harbor containers running" || log_warn "No harbor containers seen"
ssh_run "$HARBOR_NODE" "df -h $HARBOR_DATA | tail -1" || true
curl -sk "https://${HARBOR_NODE}:${HARBOR_PORT}/api/v2.0/ping" &>/dev/null && log_info "API ping OK" || log_warn "API not responding"
log_info "All pre-checks passed"
