#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "ROLLBACK" "Rolling back Harbor"
ssh_run "$HARBOR_NODE" "cd $HARBOR_HOME && docker-compose down 2>/dev/null || docker compose down" || true
ssh_run "$HARBOR_NODE" "[[ -f ${BACKUP_BASE}/harbor-yml-*.bak ]] && cp ${BACKUP_BASE}/harbor-yml-*.bak $HARBOR_HOME/harbor.yml" || true
ssh_run "$HARBOR_NODE" "cd $HARBOR_HOME && ./install.sh 2>&1" || true
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$HARBOR_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "ROLLBACK" "Harbor rollback completed"
