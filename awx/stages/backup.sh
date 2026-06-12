#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
BACKUP_TAG="awx-${ENV}-$(date +%Y%m%d%H%M%S)"; audit_started "BACKUP" "AWX backup: $BACKUP_TAG"
ssh_run "$AWX_DB_HOST" "pg_dump -U awx $AWX_DB_NAME | gzip > ${BACKUP_BASE}/awx-db-${BACKUP_TAG}.sql.gz" 2>/dev/null || log_warn "DB backup skipped"
ssh_run "$AWX_NODE" "tar czf ${BACKUP_BASE}/awx-projects-${BACKUP_TAG}.tgz -C $AWX_PROJECTS ." 2>/dev/null || true
if [[ "$AWX_DEPLOY_METHOD" == "docker" ]]; then
    ssh_run "$AWX_NODE" "docker exec awx_task tar czf - -C /var/lib/awx projects/ venvs/ credentials/ 2>/dev/null > ${BACKUP_BASE}/awx-data-${BACKUP_TAG}.tgz" || true
fi
audit_success "BACKUP" "AWX backup: $BACKUP_TAG"
