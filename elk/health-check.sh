#!/bin/bash
set -euo pipefail; S="$(cd "$(dirname "$0")" && pwd)"; P="$(cd "$S/.." && pwd)"
source "$P/shared/lib/log.sh" "$P/shared/lib/notify.sh" "$S/config/shared.cfg" "$S/config/${1:-prod}.cfg"
R="ELK Health Check ($(date)):\n"; ES_NODE="${ES_NODES[0]}"
H=$(curl -s "http://${ES_NODE}:${ES_PORT}/_cluster/health" 2>/dev/null | grep -o '"status":"[^"]*"'); R+="  ES cluster: $H\n"
I=$(curl -s "http://${ES_NODE}:${ES_PORT}/_cat/indices" 2>/dev/null | wc -l); R+="  Indices: $I\n"
ping -c 1 "$KB_NODE" &>/dev/null && K=$(curl -s -o /dev/null -w '%{http_code}' "http://${KB_NODE}:${KB_PORT}" 2>/dev/null || echo "000"); R+="  Kibana: ${K:-unreachable}\n"
ssh "$LS_NODE" "systemctl is-active $LS_SERVICE" 2>/dev/null | grep -q active && R+="  Logstash: active\n" || R+="  Logstash: down\n"
echo -e "$R"; notify "ELK health check" "$R"
