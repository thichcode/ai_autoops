#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
BACKUP_TAG="zabbix-${ENV}-$(date +%Y%m%d%H%M%S)"
audit_started "BACKUP" "Zabbix backup: $BACKUP_TAG"
ssh_run "$ZABBIX_DB_HOST" "pg_dump -U zabbix $ZABBIX_DB_NAME | gzip > ${BACKUP_BASE}/zabbix-db-${BACKUP_TAG}.sql.gz" 2>/dev/null || log_warn "DB backup skipped"
ssh_run "$ZABBIX_SERVER" "tar czf ${BACKUP_BASE}/zabbix-conf-${BACKUP_TAG}.tgz -C $ZABBIX_SERVER_HOME zabbix_server.conf alertscripts/ externalscripts/" 2>/dev/null || true
audit_success "BACKUP" "Zabbix backup: $BACKUP_TAG"
