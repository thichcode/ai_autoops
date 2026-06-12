#!/bin/bash
set -euo pipefail; S="$(cd "$(dirname "$0")" && pwd)"; P="$(cd "$S/.." && pwd)"
source "$P/shared/lib/log.sh" "$P/shared/lib/notify.sh" "$S/config/shared.cfg" "$S/config/${1:-prod}.cfg"
R="Harbor Health Check ($(date)):\n"; ping -c 1 "$HARBOR_NODE" &>/dev/null && R+="  Node OK\n" || R+="  Node FAIL\n"
C=$(ssh "$HARBOR_NODE" "docker ps --format '{{.Names}}' 2>/dev/null | grep -c harbor" || echo 0); R+="  Containers running: $C\n"
curl -sk "https://${HARBOR_NODE}:${HARBOR_PORT}/api/v2.0/ping" &>/dev/null && R+="  API OK\n" || R+="  API FAIL\n"
echo -e "$R"; notify "Harbor health check" "$R"
