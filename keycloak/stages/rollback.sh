#!/bin/bash
set -euo pipefail; ENV="$1"; NODE="${CURRENT_NODE:-${KC_NODES[0]}}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "ROLLBACK" "Rolling back Keycloak on $NODE"
ssh_run "$NODE" "systemctl stop $KC_SERVICE" || true
LATEST=$(ssh_run "$NODE" "ls -dt ${BACKUP_BASE}/kc-previous-${NODE}-* 2>/dev/null | head -1" || true)
[[ -n "$LATEST" ]] && ssh_run "$NODE" "cp -a $LATEST/* $KC_HOME/" || log_warn "Previous install restore skipped"
# Restore DB
LATEST_DB=$(ssh_run "$KC_DB_HOST" "ls -t ${BACKUP_BASE}/kc-db-*.sql.gz 2>/dev/null | head -1" || true)
[[ -n "$LATEST_DB" ]] && ssh_run "$KC_DB_HOST" "gunzip -c $LATEST_DB | psql -U keycloak $KC_DB_NAME" || log_warn "DB restore skipped"
ssh_run "$NODE" "systemctl start $KC_SERVICE" || true
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "ROLLBACK" "Keycloak rollback completed"
