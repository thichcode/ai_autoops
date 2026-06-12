#!/bin/bash
set -euo pipefail; S="$(cd "$(dirname "$0")" && pwd)"; P="$(cd "$S/.." && pwd)"
source "$P/shared/lib/log.sh" "$P/shared/lib/notify.sh" "$S/config/shared.cfg" "$S/config/${1:-prod}.cfg"
R="AWX Health Check ($(date)):\n"; ping -c 1 "$AWX_NODE" &>/dev/null && R+="  Node OK\n" || R+="  Node FAIL\n"
if [[ "$AWX_DEPLOY_METHOD" == "docker" ]]; then
    C=$(ssh "$AWX_NODE" "docker ps --format '{{.Names}}' 2>/dev/null | grep -c awx" || echo 0); R+="  Containers: $C\n"
fi
curl -sk "https://${AWX_NODE}:${AWX_PORT}" -o /dev/null -w '%{http_code}' 2>/dev/null | grep -q 200 && R+="  HTTPS OK\n" || R+="  HTTPS FAIL\n"
echo -e "$R"; notify "AWX health check" "$R"
