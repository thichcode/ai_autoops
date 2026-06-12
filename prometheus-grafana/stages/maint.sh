#!/bin/bash
set -euo pipefail; ENV="$1"; COMP="${CURRENT_COMP:-prometheus}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "MAINT" "Stopping $COMP"
case "$COMP" in
    prometheus) ssh_run "$PROM_NODE" "systemctl stop $PROM_SERVICE" || true ;;
    grafana) ssh_run "$GRAFANA_NODE" "systemctl stop $GRAFANA_SERVICE" || true ;;
    alertmanager) ssh_run "$ALERT_NODE" "systemctl stop $ALERT_SERVICE" || true ;;
esac
sleep 5; audit_success "MAINT" "$COMP stopped"
