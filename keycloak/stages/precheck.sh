#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/utils.sh"
check_rbac "keycloak-admins" || exit 1
for node in "${KC_NODES[@]}"; do
    ping -c 2 "$node" &>/dev/null && log_info "Node OK: $node" || { log_error "Node unreachable: $node"; exit 1; }
    curl -sk "https://${node}:${KC_PORT}/realms/master/.well-known/openid-configuration" 2>/dev/null | grep -q 'issuer' && log_info "Keycloak responding on $node" || log_warn "No response from $node"
done
ssh_run "$KC_DB_HOST" "pg_isready -q 2>/dev/null" && log_info "PostgreSQL ready" || { log_error "DB unreachable"; exit 1; }
log_info "All pre-checks passed"
