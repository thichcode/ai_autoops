#!/bin/bash
# rollback.sh — Rollback GitLab app node to previous package version
set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

NODE="${CURRENT_NODE:-${GITLAB_APP_NODES[0]}}"
audit_started "ROLLBACK" "Rolling back GitLab on $NODE"

# Stop services
ssh_run "$NODE" "gitlab-ctl stop unicorn && gitlab-ctl stop workhorse && gitlab-ctl stop sidekiq" || true

# Install previous package version
PREV_VER=$(ssh_run "$NODE" "dpkg -l | grep gitlab-ee | head -1 | awk '{print \$3}'" 2>/dev/null || echo "unknown")
log_info "Previous version: $PREV_VER. Restoring from apt cache..."
ssh_run "$NODE" "apt-get install -y --allow-downgrades gitlab-ee=$PREV_VER" || {
    log_error "Rollback via apt failed — attempting backup restore"
    # Restore from DB backup
    local LATEST_DB=$(ssh_run "$GITLAB_DB_HOST" "ls -t $GITLAB_DB_BACKUP_DIR/*.sql.gz | head -1" 2>/dev/null || echo "")
    if [[ -n "$LATEST_DB" ]]; then
        ssh_run "$GITLAB_DB_HOST" "gunzip -c $LATEST_DB | psql -U $GITLAB_DB_USER $GITLAB_DB_NAME"
    fi
}
ssh_run "$NODE" "gitlab-ctl reconfigure"
ssh_run "$NODE" "gitlab-ctl start unicorn && gitlab-ctl start workhorse"

# Re-enable in NGINX Plus upstream
local NETRC_FILE=$(mktemp)
echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC_FILE"
chmod 600 "$NETRC_FILE"
curl -s -X PATCH -d '{"weight": 1, "drain": false}' \
    "$NGINX_PLUS_API/6/upstreams/$GITLAB_LB_UPSTREAM/servers/$NODE" \
    --netrc-file "$NETRC_FILE" || true
rm -f "$NETRC_FILE"

audit_success "ROLLBACK" "Rollback completed on $NODE"
notify_warning "GitLab rollback completed" "Node $NODE rolled back"
