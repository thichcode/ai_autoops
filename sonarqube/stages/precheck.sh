#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/utils.sh"
check_rbac "sonar-admins" || exit 1
ping -c 2 "$SONAR_NODE" &>/dev/null && log_info "Node OK: $SONAR_NODE" || { log_error "Node unreachable"; exit 1; }
ssh_run "$SONAR_NODE" "systemctl is-active $SONAR_SERVICE" | grep -q active && log_info "Service active" || log_warn "Service not active"
ssh_run "$SONAR_DB_HOST" "pg_isready -q 2>/dev/null" && log_info "PostgreSQL ready" || { log_error "PostgreSQL unreachable"; exit 1; }
log_info "All pre-checks passed"
