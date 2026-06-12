#!/bin/bash
set -euo pipefail; ENV="$1"; NODE="${CURRENT_NODE:-${RUNNER_LINUX_NODES[0]}}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "ROLLBACK" "Rolling back runner on $NODE"
ssh_run "$NODE" "systemctl stop $RUNNER_SERVICE" || true
# Restore config.toml
LATEST=$(ssh_run "$NODE" "ls -t ${BACKUP_BASE}/runner-config-${NODE}-*.bak 2>/dev/null | head -1" || true)
[[ -n "$LATEST" ]] && ssh_run "$NODE" "cp $LATEST $RUNNER_CONFIG" || log_warn "Config restore skipped"
ssh_run "$NODE" "systemctl start $RUNNER_SERVICE" || true
audit_success "ROLLBACK" "Runner rollback completed on $NODE"
