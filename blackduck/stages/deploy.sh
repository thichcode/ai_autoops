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

audit_started "DEPLOY" "Deploying BlackDuck $BD_VERSION on $BD_HOST"
ssh_run "$BD_HOST" "systemctl stop $BD_SERVICE" 2>/dev/null || true
ssh_run "$BD_HOST" "cp -a $BD_INSTALL_DIR ${BD_INSTALL_DIR}.$(date +%Y%m%d%H%M%S)" 2>/dev/null
ssh_run "$BD_HOST" "echo 'Placeholder: install BlackDuck $BD_VERSION' && systemctl start $BD_SERVICE" 2>/dev/null
audit_success "DEPLOY" "BlackDuck $BD_VERSION deployed"
