#!/bin/bash
set -euo pipefail; SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; PROJECT_ROOT="$SCRIPT_DIR/.."
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/notify.sh" "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/${1:-prod}.cfg"
R="Jenkins Health Check ($(date)):\n"
ping -c 1 "$JENKINS_CONTROLLER" &>/dev/null && R+="  Controller OK: $JENKINS_CONTROLLER\n" || R+="  Controller FAIL: $JENKINS_CONTROLLER\n"
S=$(ssh "$JENKINS_CONTROLLER" "systemctl is-active $JENKINS_SERVICE" 2>/dev/null || echo "unknown"); R+="  Service: $S\n"
for a in "${JENKINS_AGENTS[@]}"; do ping -c 1 "$a" &>/dev/null && R+="  Agent OK: $a\n" || R+="  Agent FAIL: $a\n"; done
echo -e "$R"; notify "Jenkins health check" "$R"
