#!/bin/bash
set -euo pipefail; S="$(cd "$(dirname "$0")" && pwd)"; P="$(cd "$S/.." && pwd)"
source "$P/shared/lib/log.sh" "$P/shared/lib/notify.sh" "$S/config/shared.cfg" "$S/config/${1:-prod}.cfg"
R="GitLab Runner Health Check ($(date)):\n"
for node in "${RUNNER_LINUX_NODES[@]}"; do
    ping -c 1 "$node" &>/dev/null && R+="  $node: OK\n" || R+="  $node: FAIL\n"
    SVC=$(ssh "$node" "systemctl is-active $RUNNER_SERVICE" 2>/dev/null || echo "unknown"); R+="    Service: $SVC\n"
done
echo -e "$R"; notify "Runner health check" "$R"
