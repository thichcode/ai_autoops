#!/bin/bash
set -euo pipefail; ENV="$1"; NODE="${CURRENT_NODE:?}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "MAINT" "Stopping runner: $NODE"
ssh_run "$NODE" "systemctl stop $RUNNER_SERVICE" || true; sleep 5
audit_success "MAINT" "Runner stopped: $NODE"
