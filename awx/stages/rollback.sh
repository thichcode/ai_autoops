#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "ROLLBACK" "Rolling back AWX"
if [[ "$AWX_DEPLOY_METHOD" == "docker" ]]; then
    ssh_run "$AWX_NODE" "cd $AWX_HOME && docker-compose down 2>/dev/null || docker compose down" || true
fi
# Restore DB
LATEST=$(ssh_run "$AWX_DB_HOST" "ls -t ${BACKUP_BASE}/awx-db-*.sql.gz 2>/dev/null | head -1" || true)
[[ -n "$LATEST" ]] && ssh_run "$AWX_DB_HOST" "gunzip -c $LATEST | psql -U awx $AWX_DB_NAME" || log_warn "DB restore skipped"
if [[ "$AWX_DEPLOY_METHOD" == "docker" ]]; then
    ssh_run "$AWX_NODE" "cd $AWX_HOME && docker-compose up -d 2>/dev/null || docker compose up -d" || true
else
    ssh_run "$AWX_NODE" "systemctl start awx" || true
fi
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$AWX_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "ROLLBACK" "AWX rollback completed"
