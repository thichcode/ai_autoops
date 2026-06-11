#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/utils.sh"
ping -c 2 "$JENKINS_CONTROLLER" &>/dev/null && log_info "Controller OK: $JENKINS_CONTROLLER" || { log_error "Controller unreachable"; exit 1; }
ssh_run "$JENKINS_CONTROLLER" "systemctl is-active $JENKINS_SERVICE" | grep -q active || log_warn "Service not active"
for agent in "${JENKINS_AGENTS[@]}"; do
    ping -c 1 "$agent" &>/dev/null && log_info "Agent OK: $agent" || log_warn "Agent unreachable: $agent"
done
