#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/utils.sh"
check_rbac "awx-admins" || exit 1
ping -c 2 "$AWX_NODE" &>/dev/null && log_info "Node OK: $AWX_NODE" || { log_error "Node unreachable"; exit 1; }
if [[ "$AWX_DEPLOY_METHOD" == "docker" ]]; then
    ssh_run "$AWX_NODE" "docker ps --format '{{.Names}}' 2>/dev/null | grep -q awx" && log_info "AWX containers running" || log_warn "No AWX containers seen"
else
    ssh_run "$AWX_NODE" "systemctl is-active awx 2>/dev/null | grep -q active" && log_info "AWX service active" || log_warn "AWX service not active"
fi
ssh_run "$AWX_DB_HOST" "pg_isready -q 2>/dev/null" && log_info "PostgreSQL ready" || { log_error "DB unreachable"; exit 1; }
log_info "All pre-checks passed"
