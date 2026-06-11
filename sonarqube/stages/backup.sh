#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
BACKUP_TAG="sonar-${ENV}-$(date +%Y%m%d%H%M%S)"
audit_started "BACKUP" "SonarQube backup: $BACKUP_TAG"
ssh_run "$SONAR_DB_HOST" "pg_dump -U sonar $SONAR_DB_NAME | gzip > ${BACKUP_BASE}/sonar-db-${BACKUP_TAG}.sql.gz" 2>/dev/null || log_warn "DB backup skipped"
ssh_run "$SONAR_NODE" "tar czf ${BACKUP_BASE}/sonar-conf-${BACKUP_TAG}.tgz -C $SONAR_HOME conf/ extensions/" 2>/dev/null || true
audit_success "BACKUP" "SonarQube backup: $BACKUP_TAG"
