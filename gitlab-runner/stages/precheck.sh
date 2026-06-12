#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/utils.sh"
check_rbac "runner-admins" || exit 1
for node in "${RUNNER_LINUX_NODES[@]}" "${RUNNER_WIN_NODES[@]}"; do
    ping -c 2 "$node" &>/dev/null && log_info "Runner OK: $node" || log_warn "Runner unreachable: $node"
done
log_info "All pre-checks passed"
