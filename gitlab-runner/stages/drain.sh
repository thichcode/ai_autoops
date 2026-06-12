#!/bin/bash
set -euo pipefail; ENV="$1"; NODE="${CURRENT_NODE:?}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "DRAIN" "Pausing runner: $NODE"
ssh_run "$NODE" "gitlab-runner pause 2>/dev/null" || true
# Also disable via GitLab API if token available
sleep 5; audit_success "DRAIN" "Runner paused: $NODE"
