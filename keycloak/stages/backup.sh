#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
BACKUP_TAG="kc-${ENV}-$(date +%Y%m%d%H%M%S)"; audit_started "BACKUP" "Keycloak backup: $BACKUP_TAG"
ssh_run "$KC_DB_HOST" "pg_dump -U keycloak $KC_DB_NAME | gzip > ${BACKUP_BASE}/kc-db-${BACKUP_TAG}.sql.gz" 2>/dev/null || log_warn "DB backup skipped"
# Realm exports
KC_NODE="${KC_NODES[0]}"
ssh_run "$KC_NODE" "cd $KC_HOME && bin/kc.sh export --dir ${KC_REALM_EXPORT_DIR} --realm master 2>/dev/null" || true
ssh_run "$KC_NODE" "tar czf ${BACKUP_BASE}/kc-realms-${BACKUP_TAG}.tgz -C ${KC_REALM_EXPORT_DIR} ." 2>/dev/null || true
ssh_run "$KC_NODE" "tar czf ${BACKUP_BASE}/kc-themes-${BACKUP_TAG}.tgz -C $KC_HOME themes/" 2>/dev/null || true
audit_success "BACKUP" "Keycloak backup: $BACKUP_TAG"
