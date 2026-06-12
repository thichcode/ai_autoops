#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/utils.sh"
check_rbac "pg-admins" || exit 1
for node in "$PROM_NODE" "$GRAFANA_NODE" "$ALERT_NODE"; do
    ping -c 2 "$node" &>/dev/null && log_info "OK: $node" || { log_error "Unreachable: $node"; exit 1; }
done
curl -s "http://${PROM_NODE}:${PROM_PORT}/-/ready" 2>/dev/null | grep -q 'Ready' && log_info "Prometheus ready" || log_warn "Prometheus not ready"
curl -s "http://${GRAFANA_NODE}:${GRAFANA_PORT}/api/health" 2>/dev/null | grep -q 'ok' && log_info "Grafana healthy" || log_warn "Grafana not healthy"
log_info "All pre-checks passed"
