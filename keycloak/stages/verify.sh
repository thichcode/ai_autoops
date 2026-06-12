#!/bin/bash
set -euo pipefail; ENV="$1"; NODE="${CURRENT_NODE:?}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "VERIFY" "Verifying Keycloak on $NODE"
ssh_run "$NODE" "systemctl start $KC_SERVICE" || true; sleep 30
ssh_run "$NODE" "systemctl is-active $KC_SERVICE" | grep -q active || { log_error "Service not active"; exit 1; }
curl -sk "https://${NODE}:${KC_PORT}/realms/master/.well-known/openid-configuration" 2>/dev/null | grep -q 'issuer' && log_info "OIDC OK" || log_warn "OIDC not available"
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "VERIFY" "Node verified: $NODE"
