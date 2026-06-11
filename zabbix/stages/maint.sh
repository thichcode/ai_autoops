#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "MAINT" "Stopping Zabbix services"
for srv in "$ZABBIX_SERVICE_SERVER" "$ZABBIX_SERVICE_AGENT"; do
    ssh_run "$ZABBIX_SERVER" "systemctl stop $srv" || true
done
for px in "${ZABBIX_PROXIES[@]}"; do
    ssh_run "$px" "systemctl stop $ZABBIX_SERVICE_PROXY" || true
done
sleep 10; audit_success "MAINT" "Zabbix services stopped"
