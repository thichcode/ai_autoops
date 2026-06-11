#!/bin/bash
set -euo pipefail; SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; PROJECT_ROOT="$SCRIPT_DIR/.."
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/notify.sh" "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/${1:-prod}.cfg"
R="Nexus Health Check ($(date)):\n"
ping -c 1 "$NEXUS_NODE" &>/dev/null && R+="  Node OK\n" || R+="  Node FAIL\n"
S=$(ssh "$NEXUS_NODE" "systemctl is-active $NEXUS_SERVICE" 2>/dev/null || echo "unknown"); R+="  Service: $S\n"
H=$(curl -s -o /dev/null -w '%{http_code}' "http://$NEXUS_NODE:$NEXUS_PORT" 2>/dev/null || echo "000"); R+="  HTTP: $H\n"
echo -e "$R"; notify "Nexus health check" "$R"
