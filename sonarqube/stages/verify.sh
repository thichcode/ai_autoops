#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "VERIFY" "Verifying SonarQube"
ssh_run "$SONAR_NODE" "systemctl start $SONAR_SERVICE" || true; sleep 60
ssh_run "$SONAR_NODE" "systemctl is-active $SONAR_SERVICE" | grep -q active || { log_error "Service not active"; exit 1; }
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://${SONAR_NODE}:${SONAR_PORT}" 2>/dev/null || echo "000")
[[ "$HTTP" == "200" ]] && log_info "HTTP OK" || log_warn "HTTP: $HTTP"
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$SONAR_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "VERIFY" "SonarQube verified"
