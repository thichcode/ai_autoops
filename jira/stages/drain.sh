#!/bin/bash
# drain.sh — Remove Jira node from NGINX Plus upstream

set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

NODE="${CURRENT_NODE:?CURRENT_NODE not set}"
audit_started "DRAIN" "Draining node: $NODE"

log_info "Setting node $NODE to draining state in NGINX Plus upstream $NGINX_UPSTREAM_NAME"
local NETRC_FILE
NETRC_FILE=$(mktemp)
echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC_FILE"
chmod 600 "$NETRC_FILE"
curl -s -X PATCH -d '{"weight": 0, "drain": true}' \
    "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" \
    --netrc-file "$NETRC_FILE" || true
rm -f "$NETRC_FILE"

log_info "Waiting for active connections to drain..."
sleep 30

audit_success "DRAIN" "Node drained: $NODE"
log_info "Node $NODE drained successfully"
