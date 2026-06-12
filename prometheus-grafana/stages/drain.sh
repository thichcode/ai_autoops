#!/bin/bash
set -euo pipefail; ENV="$1"; COMP="${CURRENT_COMP:-prometheus}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "DRAIN" "Draining $COMP"
case "$COMP" in
    grafana) local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
        curl -s -X PATCH -d '{"weight": 0}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$GRAFANA_NODE" --netrc-file "$NETRC" || true; rm -f "$NETRC" ;;
    alertmanager) ;;  # alertmanager is standalone, no LB drain needed
    *) ;;
esac
sleep 5; audit_success "DRAIN" "$COMP drained"
