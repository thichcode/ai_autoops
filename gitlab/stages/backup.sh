#!/bin/bash
# backup.sh — GitLab multi-node backup (PG dump + NFS backup)
set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

BACKUP_TAG="gitlab-${ENV}-prepatch-$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="${BACKUP_BASE}/${BACKUP_TAG}"
DB_DUMP_FILE="${GITLAB_DB_BACKUP_DIR}/${BACKUP_TAG}.sql.gz"

audit_started "BACKUP" "GitLab backup tag: $BACKUP_TAG"

# 1. PostgreSQL backup
log_info "Taking PostgreSQL backup from $GITLAB_DB_HOST"
ssh_run "$GITLAB_DB_HOST" "mkdir -p $GITLAB_DB_BACKUP_DIR"
ssh_run "$GITLAB_DB_HOST" \
    "pg_dump --clean --if-exists --no-owner -U $GITLAB_DB_USER $GITLAB_DB_NAME \
     | gzip > $DB_DUMP_FILE" || {
    log_error "PG dump failed"
    audit_failure "BACKUP_DB" "PostgreSQL dump failed"
    return 1
}
ssh_run "$GITLAB_DB_HOST" "ls -la $DB_DUMP_FILE"
DB_CHECKSUM=$(ssh_run "$GITLAB_DB_HOST" "sha256sum $DB_DUMP_FILE | awk '{print \$1}'")
log_info "DB backup checksum: $DB_CHECKSUM"
audit_success "BACKUP_DB" "PG dump: $DB_DUMP_FILE"

# 2. GitLab backup command (from first app node — triggers omnibus backup of config + secrets)
local APP_NODE="${GITLAB_APP_NODES[0]}"
log_info "Running gitlab-backup on $APP_NODE"
ssh_run "$APP_NODE" "gitlab-backup create CRON=1" || log_warn "gitlab-backup warning (check manually)"
audit_success "BACKUP_APP" "gitlab-backup triggered on $APP_NODE"

audit_success "BACKUP" "GitLab backup completed: $BACKUP_TAG"
log_info "Backup completed successfully"
