#!/bin/bash
set -euo pipefail; ENV="$1"; COMP="${CURRENT_COMP:-prometheus}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "VERIFY" "Verifying $COMP"
case "$COMP" in
    prometheus)
        ssh_run "$PROM_NODE" "systemctl start $PROM_SERVICE" || true; sleep 15
        ssh_run "$PROM_NODE" "systemctl is-active $PROM_SERVICE" | grep -q active || { log_error "Prometheus not active"; exit 1; }
        curl -s "http://${PROM_NODE}:${PROM_PORT}/-/ready" 2>/dev/null | grep -q Ready && log_info "Prometheus ready" || log_warn "Not ready" ;;
    grafana)
        ssh_run "$GRAFANA_NODE" "systemctl start $GRAFANA_SERVICE" || true; sleep 15
        curl -s "http://${GRAFANA_NODE}:${GRAFANA_PORT}/api/health" 2>/dev/null | grep -q ok && log_info "Grafana healthy" || log_warn "Not healthy"
        local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
        curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$GRAFANA_NODE" --netrc-file "$NETRC" || true; rm -f "$NETRC" ;;
    alertmanager)
        ssh_run "$ALERT_NODE" "systemctl start $ALERT_SERVICE" || true; sleep 10 ;;
esac
audit_success "VERIFY" "$COMP verified"
