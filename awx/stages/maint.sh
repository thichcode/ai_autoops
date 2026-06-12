#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "MAINT" "Stopping AWX"
if [[ "$AWX_DEPLOY_METHOD" == "docker" ]]; then
    ssh_run "$AWX_NODE" "cd $AWX_HOME && docker-compose down 2>/dev/null || docker compose down" || true
else
    ssh_run "$AWX_NODE" "systemctl stop awx" || true
fi
sleep 10; audit_success "MAINT" "AWX stopped"
