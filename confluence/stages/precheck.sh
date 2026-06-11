#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

check_rbac "confluence-admins" || exit 1

for node in "${CONF_NODES[@]}"; do
    ping -c 2 "$node" &>/dev/null && log_info "Node OK: $node" || { log_error "Node unreachable: $node"; exit 1; }
    ssh_run "$node" "df -h $CONF_HOME | tail -1" || true
    ssh_run "$node" "mountpoint -q $NFS_MOUNT && echo NFS OK || echo NFS FAIL" 2>/dev/null || true
done

DB_HOST="${DB_HOSTS[0]}"
if ssh_run "$DB_HOST" "pg_isready -q 2>/dev/null"; then
    log_info "PostgreSQL ready on $DB_HOST"
else
    log_error "PostgreSQL unreachable on $DB_HOST"
    exit 1
fi
log_info "All pre-checks passed"
