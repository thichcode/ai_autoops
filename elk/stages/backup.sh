#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
BACKUP_TAG="elk-${ENV}-$(date +%Y%m%d%H%M%S)"; audit_started "BACKUP" "ELK backup: $BACKUP_TAG"
# ES snapshot (requires snapshot repo configured)
ES_NODE="${ES_NODES[0]}"
ssh_run "$ES_NODE" "curl -s -X PUT 'http://localhost:${ES_PORT}/_snapshot/backup_repo' -H 'Content-Type: application/json' -d '{\"type\":\"fs\",\"settings\":{\"location\":\"$ES_SNAPSHOT_DIR\"}}'" 2>/dev/null || true
ssh_run "$ES_NODE" "curl -s -X PUT 'http://localhost:${ES_PORT}/_snapshot/backup_repo/snapshot-${BACKUP_TAG}?wait_for_completion=true'" 2>/dev/null || log_warn "ES snapshot skipped"
# Kibana saved objects
curl -s -X POST "http://${KB_NODE}:${KB_PORT}/api/saved_objects/_export" -H 'kbn-xsrf: true' -H 'Content-Type: application/json' -d '{"type":["dashboard","visualization","index-pattern"]}' -o "${BACKUP_BASE}/kibana-export-${BACKUP_TAG}.ndjson" 2>/dev/null || log_warn "Kibana export skipped"
# Logstash config
ssh_run "$LS_NODE" "tar czf ${BACKUP_BASE}/logstash-conf-${BACKUP_TAG}.tgz -C $LS_HOME pipeline/ config/" 2>/dev/null || true
audit_success "BACKUP" "ELK backup: $BACKUP_TAG"
