#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/notify.sh"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/${1:-prod}.cfg"

REPORT="Confluence Health Check ($(date)):\n"
for node in "${CONF_NODES[@]}"; do
    if ping -c 1 "$node" &>/dev/null; then
        REPORT+="  ✅ $node reachable\n"
        STATUS=$(ssh "$node" "curl -s -o /dev/null -w '%{http_code}' http://localhost:8090/status" 2>/dev/null || echo "000")
        REPORT+="  HTTP status: $STATUS\n"
    else REPORT+="  ❌ $node unreachable\n"; fi
done
DB_HOST="${DB_HOSTS[0]}"
if ssh "$DB_HOST" "pg_isready -q" 2>/dev/null; then
    REPORT+="  ✅ Postgres ready\n"
else REPORT+="  ❌ Postgres unreachable\n"; fi
echo -e "$REPORT"
notify "Confluence health check" "$REPORT"
