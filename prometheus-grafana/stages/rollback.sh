#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "ROLLBACK" "Rolling back all PG components"
for node in "$PROM_NODE" "$GRAFANA_NODE" "$ALERT_NODE"; do
    ssh_run "$node" "for svc in $PROM_SERVICE $GRAFANA_SERVICE $ALERT_SERVICE; do systemctl stop \$svc 2>/dev/null || true; done" || true
done
# Restore Prometheus data
LATEST_P=$(ssh_run "$PROM_NODE" "ls -t ${BACKUP_BASE}/prometheus-data-*.tgz 2>/dev/null | head -1" || true)
[[ -n "$LATEST_P" ]] && ssh_run "$PROM_NODE" "tar xzf $LATEST_P -C $PROM_DATA/../ --strip-components=1" || log_warn "Prometheus data restore skipped"
# Restore Grafana data
LATEST_G=$(ssh_run "$GRAFANA_NODE" "ls -t ${BACKUP_BASE}/grafana-data-*.tgz 2>/dev/null | head -1" || true)
[[ -n "$LATEST_G" ]] && ssh_run "$GRAFANA_NODE" "tar xzf $LATEST_G -C $GRAFANA_DATA/../ --strip-components=1" || log_warn "Grafana data restore skipped"
ssh_run "$PROM_NODE" "systemctl start $PROM_SERVICE" || true
ssh_run "$GRAFANA_NODE" "systemctl start $GRAFANA_SERVICE" || true
ssh_run "$ALERT_NODE" "systemctl start $ALERT_SERVICE" || true
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$GRAFANA_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "ROLLBACK" "PG rollback completed"
