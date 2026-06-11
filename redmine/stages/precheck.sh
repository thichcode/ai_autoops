#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/utils.sh"
check_rbac "redmine-admins" || exit 1
for node in "${REDMINE_NODES[@]}"; do
    ping -c 2 "$node" &>/dev/null && log_info "Node OK: $node" || { log_error "Node unreachable: $node"; exit 1; }
    ssh_run "$node" "mountpoint -q $NFS_MOUNT && echo NFS OK || echo NFS FAIL" 2>/dev/null || true
done
ssh_run "$REDMINE_DB_HOST" "pg_isready -q 2>/dev/null" && log_info "PostgreSQL ready" || { log_error "DB unreachable"; exit 1; }
log_info "All pre-checks passed"
