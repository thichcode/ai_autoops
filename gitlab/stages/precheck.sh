#!/bin/bash
# precheck.sh — GitLab multi-node pre-flight checks
set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

check_rbac "gitlab" || exit 1

check_node() {
    local host="$1" label="$2"
    if ping -c 2 "$host" &>/dev/null; then
        log_info "$label reachable: $host"
    else
        log_error "$label unreachable: $host"
        return 1
    fi
}

check_nfs_mount() {
    local node="$1" mount="$2"
    if ssh_run "$node" "mountpoint -q $mount" 2>/dev/null; then
        log_info "NFS mount OK on $node: $mount"
    else
        log_warn "NFS mount not found on $node: $mount (may not be on this node)"
    fi
}

check_pg_replication() {
    local role
    role=$(ssh_run "$GITLAB_DB_HOST" \
        "psql -U $GITLAB_DB_USER -d $GITLAB_DB_NAME -c 'SELECT pg_is_in_recovery()' -t 2>/dev/null" || echo "unknown")
    log_info "PostgreSQL role on $GITLAB_DB_HOST: $([ "$role" == " f" ] && echo primary || echo replica)"
}

check_redis() {
    local ping
    ping=$(ssh_run "$GITLAB_REDIS_HOST" "redis-cli -p $GITLAB_REDIS_PORT PING" 2>/dev/null || echo "FAIL")
    if [[ "$ping" == "PONG" ]]; then
        log_info "Redis reachable on $GITLAB_REDIS_HOST:$GITLAB_REDIS_PORT"
    else
        log_error "Redis unreachable on $GITLAB_REDIS_HOST:$GITLAB_REDIS_PORT"
        return 1
    fi
}

# Check all app nodes
for node in "${GITLAB_APP_NODES[@]}"; do
    check_node "$node" "App node"
    ssh_run "$node" "df -h $GITLAB_HOME | tail -1"
done

# Check NFS nodes
for nfs in "${GITLAB_NFS_NODES[@]}"; do
    check_node "$nfs" "NFS node"
done

# Check NFS mounts (from first app node)
for i in "${!GITLAB_NFS_EXPORTS[@]}"; do
    check_nfs_mount "${GITLAB_APP_NODES[0]}" "${GITLAB_NFS_MOUNTS[$i]}"
done

# Check DB + Redis
check_node "$GITLAB_DB_HOST" "Database"
check_pg_replication
check_node "$GITLAB_REDIS_HOST" "Redis"
check_redis

log_info "All pre-checks passed"
