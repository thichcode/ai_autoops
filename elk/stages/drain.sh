#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "DRAIN" "Disabling log shipping and LB"
# Stop Logstash to stop new data flow
ssh_run "$LS_NODE" "systemctl stop $LS_SERVICE" || true
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 0}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$KB_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; sleep 10; audit_success "DRAIN" "ELK drained"
