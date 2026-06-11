#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "DEPLOY" "Deploying Zabbix $ZABBIX_VERSION"
ssh_run "$ZABBIX_SERVER" "wget -q ${ZABBIX_DOWNLOAD_URL} -O /tmp/zabbix-release.rpm && rpm -Uvh /tmp/zabbix-release.rpm 2>/dev/null; yum update -y zabbix-server-* zabbix-agent-* 2>/dev/null || apt-get update -qq && apt-get install --only-upgrade -y zabbix-server-pgsql zabbix-agent 2>/dev/null" || { log_error "Deploy failed"; exit 1; }
for px in "${ZABBIX_PROXIES[@]}"; do
    ssh_run "$px" "yum update -y zabbix-proxy-* 2>/dev/null || apt-get update -qq && apt-get install --only-upgrade -y zabbix-proxy-pgsql 2>/dev/null" || true
done
audit_success "DEPLOY" "Zabbix $ZABBIX_VERSION deployed"
