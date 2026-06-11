#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/utils.sh"
check_rbac "nexus-admins" || exit 1
ping -c 2 "$NEXUS_NODE" &>/dev/null && log_info "Node OK: $NEXUS_NODE" || { log_error "Node unreachable"; exit 1; }
ssh_run "$NEXUS_NODE" "systemctl is-active $NEXUS_SERVICE" | grep -q active && log_info "Service active" || log_warn "Service not active"
ssh_run "$NEXUS_NODE" "df -h $NEXUS_DATA | tail -1" || true
log_info "All pre-checks passed"
