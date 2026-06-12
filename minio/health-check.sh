#!/bin/bash
set -euo pipefail; S="$(cd "$(dirname "$0")" && pwd)"; P="$(cd "$S/.." && pwd)"
source "$P/shared/lib/log.sh" "$P/shared/lib/notify.sh" "$S/config/shared.cfg" "$S/config/${1:-prod}.cfg"
R="MinIO Health Check ($(date)):\n"; N="${MINIO_NODES[0]}"; A="${N%:*}"; P="${N#*:}"
curl -s "http://${A}:${P}/minio/health/live" 2>/dev/null | grep -q ok && R+="  S3 API: OK\n" || R+="  S3 API: FAIL\n"
curl -s "http://${A}:${MINIO_CONSOLE_PORT}" -o /dev/null -w '%{http_code}' 2>/dev/null | grep -q 200 && R+="  Console: OK\n" || R+="  Console: FAIL\n"
ssh "$A" "systemctl is-active $MINIO_SERVICE" 2>/dev/null | grep -q active && R+="  Service: active\n" || R+="  Service: down\n"
echo -e "$R"; notify "MinIO health check" "$R"
