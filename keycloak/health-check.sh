#!/bin/bash
set -euo pipefail; S="$(cd "$(dirname "$0")" && pwd)"; P="$(cd "$S/.." && pwd)"
source "$P/shared/lib/log.sh" "$P/shared/lib/notify.sh" "$S/config/shared.cfg" "$S/config/${1:-prod}.cfg"
R="Keycloak Health Check ($(date)):\n"
for n in "${KC_NODES[@]}"; do
    ping -c 1 "$n" &>/dev/null && R+="  $n: OK" || R+="  $n: FAIL"
    S=$(ssh "$n" "systemctl is-active $KC_SERVICE" 2>/dev/null || echo "unknown"); R+=" ($S)\n"
done
issuer=$(curl -sk "https://${KC_NODES[0]}:${KC_PORT}/realms/master/.well-known/openid-configuration" 2>/dev/null | grep -o '"issuer":"[^"]*"' || echo "unknown"); R+="  Issuer: $issuer\n"
echo -e "$R"; notify "Keycloak health check" "$R"
