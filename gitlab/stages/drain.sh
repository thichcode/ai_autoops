#!/bin/bash
# drain.sh — Remove GitLab app node from load balancer
set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

NODE="${CURRENT_NODE:?CURRENT_NODE not set}"
audit_started "DRAIN" "Draining app node: $NODE"

# Remove node from NGINX Plus upstream
log_info "Removing $NODE from NGINX Plus upstream $GITLAB_LB_UPSTREAM"
local NETRC_FILE=$(mktemp)
echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC_FILE"
chmod 600 "$NETRC_FILE"
curl -s -X PATCH -d '{"weight": 0, "drain": true}' \
    "$NGINX_PLUS_API/6/upstreams/$GITLAB_LB_UPSTREAM/servers/$NODE" \
    --netrc-file "$NETRC_FILE" || log_warn "NGINX Plus API drain failed — check LB config"
rm -f "$NETRC_FILE"

log_info "Waiting for active requests to drain..."
sleep 15

audit_success "DRAIN" "App node drained: $NODE"
