#!/bin/bash
# health-check.sh — Full GitLab multi-node health report
# Usage: ./health-check.sh [env]
set -euo pipefail

ENV="${1:-prod}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"

echo "=========================================="
echo "  GitLab Health Check - $ENV"
echo "  $(date -u)"
echo "=========================================="

echo ""
echo "--- App Nodes ---"
for node in "${GITLAB_APP_NODES[@]}"; do
    echo "  Node: $node"
    echo -n "    Ping: "; ping -c 1 -W 2 "$node" &>/dev/null && echo "OK" || echo "FAIL"
    echo -n "    Services: "
    ssh "$node" "gitlab-ctl status | head -5" 2>/dev/null || echo "FAILED"
    echo -n "    Disk: "
    ssh "$node" "df -h /var/opt/gitlab | tail -1 | awk '{print \$3 \"/\" \$2 \" (\" \$5 \")\"}'" 2>/dev/null || echo "unknown"
done

echo ""
echo "--- Database: $GITLAB_DB_HOST ---"
echo -n "  PostgreSQL: "
ssh "$GITLAB_DB_HOST" "psql -U $GITLAB_DB_USER -d $GITLAB_DB_NAME -c 'SELECT version();'" 2>/dev/null || echo "FAILED"
echo -n "  Replication: "
ssh "$GITLAB_DB_HOST" "psql -U $GITLAB_DB_USER -d $GITLAB_DB_NAME -c \"SELECT pg_is_in_recovery();\"" 2>/dev/null || echo "FAILED"

echo ""
echo "--- Redis: $GITLAB_REDIS_HOST:$GITLAB_REDIS_PORT ---"
echo -n "  Ping: "
ssh "$GITLAB_REDIS_HOST" "redis-cli -p $GITLAB_REDIS_PORT PING" 2>/dev/null || echo "FAILED"
echo -n "  Memory: "
ssh "$GITLAB_REDIS_HOST" "redis-cli -p $GITLAB_REDIS_PORT INFO memory | grep used_memory_human" 2>/dev/null || echo "FAILED"

echo ""
echo "--- NFS Nodes ---"
for nfs in "${GITLAB_NFS_NODES[@]}"; do
    echo -n "  $nfs: "
    ping -c 1 -W 2 "$nfs" &>/dev/null && echo "OK" || echo "FAIL"
done

echo ""
echo "--- NFS Mounts (from ${GITLAB_APP_NODES[0]}) ---"
for mount in "${GITLAB_NFS_MOUNTS[@]}"; do
    echo -n "  $mount: "
    ssh "${GITLAB_APP_NODES[0]}" "mountpoint -q $mount && echo OK || echo NOT MOUNTED" 2>/dev/null || echo "FAILED"
done

echo ""
echo "=========================================="
echo "Health check complete."
