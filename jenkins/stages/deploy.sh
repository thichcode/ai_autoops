#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "DEPLOY" "Deploying Jenkins $JENKINS_VERSION"
ssh_run "$JENKINS_CONTROLLER" "cp $JENKINS_HOME/jenkins.war $JENKINS_HOME/jenkins.war.bak 2>/dev/null; wget -q $JENKINS_JAR_URL -O /tmp/jenkins.war && mv /tmp/jenkins.war $JENKINS_HOME/jenkins.war" || { log_error "Jenkins war update failed"; exit 1; }
audit_success "DEPLOY" "Jenkins $JENKINS_VERSION deployed"
