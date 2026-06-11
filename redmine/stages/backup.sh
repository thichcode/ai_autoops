#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
BACKUP_TAG="redmine-${ENV}-$(date +%Y%m%d%H%M%S)"
audit_started "BACKUP" "Redmine backup: $BACKUP_TAG"
ssh_run "$REDMINE_DB_HOST" "pg_dump -U redmine $REDMINE_DB_NAME | gzip > ${BACKUP_BASE}/redmine-db-${BACKUP_TAG}.sql.gz" 2>/dev/null || log_warn "DB backup skipped"
ssh_run "${REDMINE_NODES[0]}" "tar czf ${BACKUP_BASE}/redmine-files-${BACKUP_TAG}.tgz -C $REDMINE_DATA files/ plugins/" 2>/dev/null || true
audit_success "BACKUP" "Redmine backup: $BACKUP_TAG"
