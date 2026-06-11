#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "VERIFY" "Verifying Jenkins controller"
ssh_run "$JENKINS_CONTROLLER" "systemctl start $JENKINS_SERVICE" || true; sleep 45
ssh_run "$JENKINS_CONTROLLER" "systemctl is-active $JENKINS_SERVICE" | grep -q active || { log_error "Service not active"; exit 1; }
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://${JENKINS_CONTROLLER}:${JENKINS_PORT}" 2>/dev/null || echo "000")
log_info "HTTP status: $HTTP"; [[ "$HTTP" == "200" || "$HTTP" == "403" ]] || log_warn "Unexpected HTTP code"
for agent in "${JENKINS_AGENTS[@]}"; do
    ssh_run "$JENKINS_CONTROLLER" "jenkins-cli connect-node '$agent' 2>/dev/null" || true
done
audit_success "VERIFY" "Jenkins verified"
