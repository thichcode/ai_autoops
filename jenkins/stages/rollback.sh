#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "ROLLBACK" "Rolling back Jenkins"
ssh_run "$JENKINS_CONTROLLER" "systemctl stop $JENKINS_SERVICE" || true
ssh_run "$JENKINS_CONTROLLER" "[[ -f $JENKINS_HOME/jenkins.war.bak ]] && cp $JENKINS_HOME/jenkins.war.bak $JENKINS_HOME/jenkins.war" || true
ssh_run "$JENKINS_CONTROLLER" "systemctl start $JENKINS_SERVICE" || true
audit_success "ROLLBACK" "Jenkins rollback completed"
