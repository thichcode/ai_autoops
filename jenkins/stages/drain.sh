#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "DRAIN" "Disconnecting Jenkins agents"
for agent in "${JENKINS_AGENTS[@]}"; do
    ssh_run "$JENKINS_CONTROLLER" "jenkins-cli disconnect-node '$agent' 2>/dev/null" || true
    log_info "Disconnected: $agent"
done
sleep 10
audit_success "DRAIN" "All agents disconnected"
