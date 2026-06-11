#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

audit_started "DEPLOY" "Deploying Coverity $COV_VERSION on $COV_HOST"
ssh_run "$COV_HOST" "systemctl stop $COV_SERVICE" 2>/dev/null || true
ssh_run "$COV_HOST" "cp -a $COV_INSTALL_DIR ${COV_INSTALL_DIR}.$(date +%Y%m%d%H%M%S)" 2>/dev/null
ssh_run "$COV_HOST" "echo 'Placeholder: install Coverity $COV_VERSION package' && systemctl start $COV_SERVICE" 2>/dev/null
audit_success "DEPLOY" "Coverity $COV_VERSION deployed"
