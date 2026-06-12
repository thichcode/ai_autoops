#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
BACKUP_TAG="pg-${ENV}-$(date +%Y%m%d%H%M%S)"; audit_started "BACKUP" "Prometheus+Grafana backup: $BACKUP_TAG"
# Prometheus TSDB snapshot
ssh_run "$PROM_NODE" "curl -s -X POST 'http://localhost:${PROM_PORT}/api/v1/admin/tsdb/snapshot' 2>/dev/null | grep -o 'snapshot/[^\"']*' | head -1" || log_warn "Prometheus snapshot skipped"
ssh_run "$PROM_NODE" "tar czf ${BACKUP_BASE}/prometheus-data-${BACKUP_TAG}.tgz -C $PROM_DATA . --exclude='wal'" 2>/dev/null || true
ssh_run "$PROM_NODE" "cp $PROM_HOME/prometheus.yml ${BACKUP_BASE}/prometheus-yml-${BACKUP_TAG}.bak" 2>/dev/null || true
# Grafana DB + dashboards
ssh_run "$GRAFANA_NODE" "tar czf ${BACKUP_BASE}/grafana-data-${BACKUP_TAG}.tgz -C $GRAFANA_DATA ." 2>/dev/null || log_warn "Grafana backup skipped"
# Alertmanager config
ssh_run "$ALERT_NODE" "cp $ALERT_HOME/alertmanager.yml ${BACKUP_BASE}/alertmanager-yml-${BACKUP_TAG}.bak" 2>/dev/null || true
audit_success "BACKUP" "PG backup: $BACKUP_TAG"
