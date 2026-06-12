#!/bin/bash
set -euo pipefail; ENV="$1"; COMP="${CURRENT_COMP:-prometheus}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "DEPLOY" "Deploying $COMP"
case "$COMP" in
    prometheus)
        ssh_run "$PROM_NODE" "wget -q https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz -O /tmp/prometheus.tar.gz && tar xzf /tmp/prometheus.tar.gz -C /opt/ && rm -f /opt/prometheus && ln -sf /opt/prometheus-${PROM_VERSION}.linux-amd64 /opt/prometheus" || { log_error "Prometheus deploy failed"; exit 1; } ;;
    grafana)
        ssh_run "$GRAFANA_NODE" "wget -q https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz -O /tmp/grafana.tar.gz && tar xzf /tmp/grafana.tar.gz -C /opt/ && rm -f /opt/grafana && ln -sf /opt/grafana-v${GRAFANA_VERSION} /opt/grafana" || { log_error "Grafana deploy failed"; exit 1; } ;;
    alertmanager)
        ssh_run "$ALERT_NODE" "wget -q https://github.com/prometheus/alertmanager/releases/download/v${PROM_VERSION}/alertmanager-${PROM_VERSION}.linux-amd64.tar.gz -O /tmp/alertmanager.tar.gz && tar xzf /tmp/alertmanager.tar.gz -C /opt/ && rm -f /opt/alertmanager && ln -sf /opt/alertmanager-${PROM_VERSION}.linux-amd64 /opt/alertmanager" || log_warn "Alertmanager deploy failed" ;;
esac
audit_success "DEPLOY" "$COMP deployed"
