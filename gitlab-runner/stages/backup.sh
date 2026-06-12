#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
BACKUP_TAG="runner-${ENV}-$(date +%Y%m%d%H%M%S)"; audit_started "BACKUP" "Runner backup: $BACKUP_TAG"
for node in "${RUNNER_LINUX_NODES[@]}"; do
    ssh_run "$node" "[[ -f $RUNNER_CONFIG ]] && cp $RUNNER_CONFIG ${BACKUP_BASE}/runner-config-${node}-${BACKUP_TAG}.bak" || true
    ssh_run "$node" "docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q runner && docker export \$(docker ps -q) 2>/dev/null > ${BACKUP_BASE}/runner-docker-cache-${node}-${BACKUP_TAG}.tar" || true
done
audit_success "BACKUP" "Runner backup: $BACKUP_TAG"
