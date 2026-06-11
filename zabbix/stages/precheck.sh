#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/utils.sh"
check_rbac "zabbix-admins" || exit 1
for srv in "$ZABBIX_SERVER" "$ZABBIX_WEB_NODE"; do
    ping -c 2 "$srv" &>/dev/null && log_info "OK: $srv" || { log_error "Unreachable: $srv"; exit 1; }
done
ssh_run "$ZABBIX_SERVER" "systemctl is-active $ZABBIX_SERVICE_SERVER" | grep -q active || log_warn "Server not active"
for px in "${ZABBIX_PROXIES[@]}"; do
    ping -c 1 "$px" &>/dev/null && log_info "Proxy OK: $px" || log_warn "Proxy unreachable: $px"
done
ssh_run "$ZABBIX_DB_HOST" "pg_isready -q 2>/dev/null" && log_info "PG ready" || { log_error "DB unreachable"; exit 1; }
log_info "All pre-checks passed"
