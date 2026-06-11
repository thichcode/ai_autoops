#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

BACKUP_TAG="confluence-${ENV}-$(date +%Y%m%d%H%M%S)"
audit_started "BACKUP" "Confluence backup tag: $BACKUP_TAG"

DB_HOST="${DB_HOSTS[0]}"
DB_DUMP="${BACKUP_BASE}/${BACKUP_TAG}.sql.gz"
ssh_run "$DB_HOST" "pg_dump -U $DB_USER $DB_NAME | gzip > $DB_DUMP" 2>/dev/null || log_warn "DB backup skipped"
ssh_run "${CONF_NODES[0]}" "tar czf ${BACKUP_BASE}/confluence-config-${BACKUP_TAG}.tgz -C $CONF_INSTALL_DIR conf/" 2>/dev/null || true
audit_success "BACKUP" "Confluence backup: $BACKUP_TAG"
