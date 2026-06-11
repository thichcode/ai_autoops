#!/bin/bash
# verify.sh — Verify GitLab app node health after deploy
set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

NODE="${CURRENT_NODE:?CURRENT_NODE not set}"
audit_started "VERIFY" "Verifying GitLab on $NODE"

# Start services
log_info "Starting services on $NODE"
ssh_run "$NODE" "gitlab-ctl start unicorn && gitlab-ctl start workhorse" || {
    log_error "Failed to start services on $NODE"
    return 1
}
sleep 20

# Check all services
SERVICES=$(ssh_run "$NODE" "gitlab-ctl status" 2>/dev/null || echo "FAIL")
echo "$SERVICES"
if echo "$SERVICES" | grep -q "down"; then
    log_error "Some GitLab services are down on $NODE"
    audit_failure "VERIFY" "Services down on $NODE"; return 1
fi
log_info "All services active on $NODE"

# HTTP health check
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$NODE/-/health" 2>/dev/null || echo "000")
log_info "Health endpoint on $NODE: $HTTP_STATUS"

# Re-enable in NGINX Plus upstream
log_info "Re-enabling $NODE in NGINX Plus upstream $GITLAB_LB_UPSTREAM"
local NETRC_FILE=$(mktemp)
echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC_FILE"
chmod 600 "$NETRC_FILE"
curl -s -X PATCH -d '{"weight": 1, "drain": false}' \
    "$NGINX_PLUS_API/6/upstreams/$GITLAB_LB_UPSTREAM/servers/$NODE" \
    --netrc-file "$NETRC_FILE" || log_warn "NGINX Plus API re-enable failed — check LB manually"
rm -f "$NETRC_FILE"

audit_success "VERIFY" "Node verified and re-enabled: $NODE"
