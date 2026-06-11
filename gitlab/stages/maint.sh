#!/bin/bash
# maint.sh — Stop GitLab services on app node (Rails, Sidekiq, Workhorse)
set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

NODE="${CURRENT_NODE:?CURRENT_NODE not set}"
audit_started "MAINT" "Stopping GitLab services on $NODE"

# Stop only user-facing services (keep Sidekiq running to finish jobs)
log_info "Stopping unicorn/puma and workhorse on $NODE"
ssh_run "$NODE" "gitlab-ctl stop unicorn" || true
ssh_run "$NODE" "gitlab-ctl stop workhorse" || true
sleep 5

log_info "Services stopped on $NODE"
audit_success "MAINT" "Services stopped on $NODE"
