#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
BACKUP_TAG="harbor-${ENV}-$(date +%Y%m%d%H%M%S)"; audit_started "BACKUP" "Harbor backup: $BACKUP_TAG"
ssh_run "$HARBOR_NODE" "docker exec harbor-db pg_dump -U harbor $HARBOR_DB_NAME 2>/dev/null | gzip > ${BACKUP_BASE}/harbor-db-${BACKUP_TAG}.sql.gz" || log_warn "DB backup skipped"
ssh_run "$HARBOR_NODE" "tar czf ${BACKUP_BASE}/harbor-data-${BACKUP_TAG}.tgz -C $HARBOR_DATA . --exclude='database' --exclude='redis'" 2>/dev/null || true
ssh_run "$HARBOR_NODE" "cp $HARBOR_HOME/harbor.yml ${BACKUP_BASE}/harbor-yml-${BACKUP_TAG}.bak" 2>/dev/null || true
audit_success "BACKUP" "Harbor backup: $BACKUP_TAG"
