#!/bin/bash
set -euo pipefail; ENV="$1"; NODE="${CURRENT_NODE:?}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "DEPLOY" "Deploying Keycloak $KC_VERSION on $NODE"
ssh_run "$NODE" "cp -a $KC_HOME ${BACKUP_BASE}/kc-previous-${NODE}-$(date +%Y%m%d%H%M%S) 2>/dev/null; wget -q ${KC_DOWNLOAD_URL/\{version\}/$KC_VERSION} -O /tmp/keycloak.tar.gz && tar xzf /tmp/keycloak.tar.gz -C /opt/ && rm -f $KC_HOME && ln -sf /opt/keycloak-${KC_VERSION} $KC_HOME" || { log_error "Deploy failed"; exit 1; }
audit_success "DEPLOY" "Keycloak $KC_VERSION deployed on $NODE"
