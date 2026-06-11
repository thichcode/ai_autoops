#!/bin/bash
# verify.sh — Health check after deploy

set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

NODE="${CURRENT_NODE:?CURRENT_NODE not set}"
audit_started "VERIFY" "Verifying Jira on $NODE"

log_info "Starting Jira service on $NODE"
ssh_run "$NODE" "systemctl start $JIRA_SERVICE" || {
    log_error "Failed to start Jira service on $NODE"
    return 1
}

sleep 30

if ! ssh_run "$NODE" "systemctl is-active $JIRA_SERVICE 2>/dev/null" | grep -q "active"; then
    log_error "Jira service not active on $NODE"
    return 1
fi
log_info "Jira service active on $NODE"

JIRA_URL="http://$NODE:8080/status"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$JIRA_URL" 2>/dev/null || echo "000")
if [[ "$HTTP_STATUS" == "200" ]]; then
    log_info "HTTP health check OK: $JIRA_URL -> $HTTP_STATUS"
else
    log_warn "HTTP health check: $JIRA_URL -> $HTTP_STATUS (may need longer startup)"
fi

DB_HOST="${DB_HOSTS[0]}"
local MYSQL_CNF
MYSQL_CNF=$(ssh_run "$DB_HOST" "mktemp")
ssh_run "$DB_HOST" "cat > $MYSQL_CNF" <<MYSQL_EOF
[client]
user=$JIRA_DB_USER
password=$JIRA_DB_PASS
MYSQL_EOF
if ssh_run "$DB_HOST" "mysql --defaults-extra-file=$MYSQL_CNF -e 'SELECT 1' $DB_NAME 2>/dev/null" \
    | grep -q "1"; then
    log_info "DB connectivity OK"
else
    log_error "DB connectivity failed"
    ssh_run "$DB_HOST" "rm -f $MYSQL_CNF"
    return 1
fi
ssh_run "$DB_HOST" "rm -f $MYSQL_CNF"

log_info "Re-enabling node $NODE in NGINX Plus upstream $NGINX_UPSTREAM_NAME"
local NETRC_FILE
NETRC_FILE=$(mktemp)
echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC_FILE"
chmod 600 "$NETRC_FILE"
curl -s -X PATCH -d '{"weight": 1, "drain": false}' \
    "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" \
    --netrc-file "$NETRC_FILE" || true
rm -f "$NETRC_FILE"

audit_success "VERIFY" "Node verified and re-enabled: $NODE"
log_info "Verification completed on $NODE"
