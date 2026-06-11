#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
BACKUP_TAG="jenkins-${ENV}-$(date +%Y%m%d%H%M%S)"
audit_started "BACKUP" "Jenkins backup: $BACKUP_TAG"
ssh_run "$JENKINS_CONTROLLER" "tar czf ${BACKUP_BASE}/jenkins-home-${BACKUP_TAG}.tgz -C $JENKINS_HOME . --exclude='workspace' --exclude='builds'" 2>/dev/null || log_warn "JENKINS_HOME backup skipped"
ssh_run "$JENKINS_CONTROLLER" "jenkins-cli list-plugins 2>/dev/null > ${BACKUP_BASE}/plugins-${BACKUP_TAG}.txt" || true
audit_success "BACKUP" "Jenkins backup: $BACKUP_TAG"
