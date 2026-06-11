#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "MAINT" "Stopping Jenkins controller"
ssh_run "$JENKINS_CONTROLLER" "systemctl stop $JENKINS_SERVICE" || true; sleep 5
audit_success "MAINT" "Jenkins stopped"
