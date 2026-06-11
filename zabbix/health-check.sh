#!/bin/bash
set -euo pipefail; SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; PROJECT_ROOT="$SCRIPT_DIR/.."
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/notify.sh" "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/${1:-prod}.cfg"
R="Zabbix Health Check ($(date)):\n"
ping -c 1 "$ZABBIX_SERVER" &>/dev/null && R+="  Server OK\n" || R+="  Server FAIL\n"
S=$(ssh "$ZABBIX_SERVER" "systemctl is-active $ZABBIX_SERVICE_SERVER" 2>/dev/null || echo "unknown"); R+="  Zabbix Server: $S\n"
for px in "${ZABBIX_PROXIES[@]}"; do ping -c 1 "$px" &>/dev/null && R+="  Proxy $px OK\n" || R+="  Proxy $px FAIL\n"; done
ssh "$ZABBIX_DB_HOST" "pg_isready -q" 2>/dev/null && R+="  DB OK\n" || R+="  DB FAIL\n"
H=$(curl -s -o /dev/null -w '%{http_code}' "http://$ZABBIX_WEB_NODE:$ZABBIX_WEB_PORT" 2>/dev/null || echo "000"); R+="  Web: $H\n"
echo -e "$R"; notify "Zabbix health check" "$R"
