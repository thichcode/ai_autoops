#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "DEPLOY" "Deploying SonarQube $SONAR_VERSION"
ssh_run "$SONAR_NODE" "cp -a $SONAR_HOME ${BACKUP_BASE}/sonar-previous/ 2>/dev/null; wget -q ${SONAR_DOWNLOAD_URL/\{version\}/$SONAR_VERSION} -O /tmp/sonarqube.zip && unzip -qo /tmp/sonarqube.zip -d /opt/ && rm -f $SONAR_HOME && ln -sf /opt/sonarqube-${SONAR_VERSION} $SONAR_HOME" || { log_error "Deploy failed"; exit 1; }
audit_success "DEPLOY" "SonarQube $SONAR_VERSION deployed"
