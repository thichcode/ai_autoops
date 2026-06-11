#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

audit_started "VERIFY" "Verifying Coverity on $COV_HOST"
sleep 15
ssh "$COV_HOST" "systemctl is-active $COV_SERVICE" 2>/dev/null | grep -q "active" && log_info "Service active" || { log_error "Service not active"; return 1; }
CURL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$COV_HOST:$COV_WEB_PORT" 2>/dev/null || echo "000")
log_info "Web status: $CURL_STATUS"
audit_success "VERIFY" "Coverity verified on $COV_HOST"
