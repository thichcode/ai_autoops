#!/bin/bash
set -euo pipefail; S="$(cd "$(dirname "$0")" && pwd)"; P="$(cd "$S/.." && pwd)"
source "$P/shared/lib/log.sh" "$P/shared/lib/notify.sh" "$S/config/shared.cfg" "$S/config/${1:-prod}.cfg"
R="Prometheus+Grafana Health Check ($(date)):\n"
curl -s "http://${PROM_NODE}:${PROM_PORT}/-/ready" &>/dev/null && R+="  Prometheus: ready\n" || R+="  Prometheus: FAIL\n"
curl -s "http://${GRAFANA_NODE}:${GRAFANA_PORT}/api/health" 2>/dev/null | grep -q ok && R+="  Grafana: healthy\n" || R+="  Grafana: FAIL\n"
ping -c 1 "$ALERT_NODE" &>/dev/null && R+="  Alertmanager: reachable\n" || R+="  Alertmanager: FAIL\n"
echo -e "$R"; notify "PG health check" "$R"
