#!/bin/bash
set -euo pipefail; SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; PROJECT_ROOT="$SCRIPT_DIR/.."
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/notify.sh" "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/${1:-prod}.cfg"
R="Redmine Health Check ($(date)):\n"
for n in "${REDMINE_NODES[@]}"; do ping -c 1 "$n" &>/dev/null && R+="  $n OK\n" || R+="  $n FAIL\n"; done
S=$(ssh "${REDMINE_NODES[0]}" "systemctl is-active $REDMINE_SERVICE" 2>/dev/null || echo "unknown"); R+="  Service: $S\n"
ssh "$REDMINE_DB_HOST" "pg_isready -q" 2>/dev/null && R+="  DB OK\n" || R+="  DB FAIL\n"
echo -e "$R"; notify "Redmine health check" "$R"
