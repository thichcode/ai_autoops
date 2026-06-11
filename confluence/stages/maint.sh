#!/bin/bash
set -euo pipefail
ENV="$1"; NODE="${CURRENT_NODE:?}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

audit_started "MAINT" "Stopping Confluence on $NODE"
ssh_run "$NODE" "systemctl stop $CONF_SERVICE" || true; sleep 5
audit_success "MAINT" "Service stopped on $NODE"
