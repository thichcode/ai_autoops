#!/bin/bash
set -euo pipefail
ENV="$1"; NODE="${CURRENT_NODE:?}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "VERIFY" "Verifying Redmine on $NODE"
ssh_run "$NODE" "systemctl start $REDMINE_SERVICE" || true; sleep 30
ssh_run "$NODE" "systemctl is-active $REDMINE_SERVICE" | grep -q active || { log_error "Service not active"; exit 1; }
HTTP=$(curl -s -o /dev/null -w "%{http_code}" "http://${NODE}:${REDMINE_PORT}" 2>/dev/null || echo "000")
log_info "HTTP: $HTTP"
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "VERIFY" "Node verified: $NODE"
