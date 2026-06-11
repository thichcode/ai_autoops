#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

check_rbac "coverity-admins" || exit 1
ping -c 2 "$COV_HOST" &>/dev/null && log_info "Host OK: $COV_HOST" || { log_error "Host unreachable"; exit 1; }
