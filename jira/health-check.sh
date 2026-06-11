#!/bin/bash
# health-check.sh — Full Jira cluster health report
# Usage: ./health-check.sh [env]

set -euo pipefail

ENV="${1:-prod}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

echo "=========================================="
echo "  Jira Health Check - $ENV"
echo "  $(date -u)"
echo "=========================================="

for node in "${JIRA_NODES[@]}"; do
    echo "--- Node: $node ---"
    echo -n "  Ping: "
    ping -c 1 -W 2 "$node" &>/dev/null && echo "OK" || echo "FAIL"
    echo -n "  Service: "
    status=$(ssh "$node" "systemctl is-active $JIRA_SERVICE" 2>/dev/null || echo "unknown")
    echo "$status"
    echo -n "  Disk ($JIRA_HOME): "
    ssh "$node" "df -h $JIRA_HOME | tail -1 | awk '{print \$3 \"/\" \$2 \" (\" \$5 \")\"}'" 2>/dev/null || echo "unknown"
    echo -n "  NFS Mount: "
    ssh "$node" "mountpoint -q $NFS_MOUNT && echo OK || echo FAIL" 2>/dev/null || echo "FAIL"
done

echo "--- Database: ${DB_HOSTS[0]} ---"
echo -n "  Galera cluster size: "
local MYSQL_CNF
MYSQL_CNF=$(ssh_run "${DB_HOSTS[0]}" "mktemp")
ssh_run "${DB_HOSTS[0]}" "cat > $MYSQL_CNF" <<MYSQL_EOF
[client]
user=$JIRA_DB_USER
password=$JIRA_DB_PASS
MYSQL_EOF
ssh_run "${DB_HOSTS[0]}" "mysql --defaults-extra-file=$MYSQL_CNF -e 'SHOW STATUS LIKE \"wsrep_cluster_size\"'" 2>/dev/null || echo "Connection FAILED"
ssh_run "${DB_HOSTS[0]}" "rm -f $MYSQL_CNF"

echo "=========================================="
echo "Health check complete."
