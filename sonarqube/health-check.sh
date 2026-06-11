#!/bin/bash
set -euo pipefail; SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; PROJECT_ROOT="$SCRIPT_DIR/.."
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/notify.sh" "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/${1:-prod}.cfg"
R="SonarQube Health Check ($(date)):\n"
ping -c 1 "$SONAR_NODE" &>/dev/null && R+="  Node OK\n" || R+="  Node FAIL\n"
S=$(ssh "$SONAR_NODE" "systemctl is-active $SONAR_SERVICE" 2>/dev/null || echo "unknown"); R+="  Service: $S\n"
H=$(curl -s -o /dev/null -w '%{http_code}' "http://$SONAR_NODE:$SONAR_PORT" 2>/dev/null || echo "000"); R+="  HTTP: $H\n"
ssh "$SONAR_DB_HOST" "pg_isready -q" 2>/dev/null && R+="  DB OK\n" || R+="  DB FAIL\n"
echo -e "$R"; notify "SonarQube health check" "$R"
