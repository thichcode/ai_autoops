#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "MAINT" "Stopping ELK services"
for node in "${ES_NODES[@]}"; do ssh_run "$node" "systemctl stop $ES_SERVICE" || true; done
ssh_run "$KB_NODE" "systemctl stop $KB_SERVICE" || true
sleep 15; audit_success "MAINT" "ELK services stopped"
