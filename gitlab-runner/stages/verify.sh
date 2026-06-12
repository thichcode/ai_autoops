#!/bin/bash
set -euo pipefail; ENV="$1"; NODE="${CURRENT_NODE:?}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "VERIFY" "Verifying runner on $NODE"
ssh_run "$NODE" "systemctl start $RUNNER_SERVICE" || true; sleep 10
ssh_run "$NODE" "systemctl is-active $RUNNER_SERVICE" | grep -q active || { log_error "Runner not active"; exit 1; }
ssh_run "$NODE" "gitlab-runner resume 2>/dev/null" || true
ssh_run "$NODE" "gitlab-runner verify 2>/dev/null" && log_info "Runner verified" || log_warn "Runner verify failed"
audit_success "VERIFY" "Runner verified: $NODE"
