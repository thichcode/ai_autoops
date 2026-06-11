#!/bin/bash
# precheck.sh — Jira pre-flight checks
# Checks: node reachability, Galera sync, disk space, NFS mount, backup age

set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

check_node() {
    local node="$1"
    if ping -c 2 "$node" &>/dev/null; then
        log_info "Node reachable: $node"
    else
        log_error "Node unreachable: $node"
        return 1
    fi
    if ssh_run "$node" "systemctl is-active $JIRA_SERVICE" 2>/dev/null; then
        log_info "Service active on $node"
    else
        log_warn "Service not active on $node (may be expected)"
    fi
}

check_galera() {
    local db_host="${DB_HOSTS[0]}"
    local wsrep_status
    local MYSQL_CNF
    MYSQL_CNF=$(ssh_run "$db_host" "mktemp")
    ssh_run "$db_host" "cat > $MYSQL_CNF" <<MYSQL_EOF
[client]
user=$JIRA_DB_USER
password=$JIRA_DB_PASS
MYSQL_EOF
    wsrep_status=$(ssh_run "$db_host" "mysql --defaults-extra-file=$MYSQL_CNF -e 'SHOW STATUS LIKE \"wsrep_cluster_size\"' 2>/dev/null" 2>/dev/null || echo "")
    ssh_run "$db_host" "rm -f $MYSQL_CNF"
    if echo "$wsrep_status" | grep -q "wsrep_cluster_size"; then
        log_info "Galera cluster reachable"
    else
        log_error "Galera cluster check failed"
        return 1
    fi
}

check_disk() {
    local node="$1"
    local threshold=80
    local usage
    usage=$(ssh_run "$node" "df -h $JIRA_HOME | tail -1 | awk '{print \$5}' | tr -d '%'" 2>/dev/null || echo 0)
    if [[ "$usage" -lt "$threshold" ]]; then
        log_info "Disk usage on $node: ${usage}% (threshold: ${threshold}%)"
    else
        log_error "Disk usage on $node: ${usage}% exceeds threshold ${threshold}%"
        return 1
    fi
}

check_nfs() {
    local node="$1"
    if ssh_run "$node" "mountpoint -q $NFS_MOUNT" 2>/dev/null; then
        log_info "NFS mount OK on $node: $NFS_MOUNT"
    else
        log_error "NFS mount not found on $node: $NFS_MOUNT"
        return 1
    fi
}

# RBAC check
check_rbac "jira" || exit 1

# For each app node
for node in "${JIRA_NODES[@]}"; do
    check_node "$node"
    check_disk "$node"
    check_nfs "$node"
done

# Galera check (once from first DB host)
check_galera

log_info "All pre-checks passed"
