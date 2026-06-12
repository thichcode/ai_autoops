#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "DEPLOY" "Deploying Harbor $HARBOR_VERSION"
ssh_run "$HARBOR_NODE" "cd $HARBOR_HOME && wget -q ${HARBOR_INSTALLER_URL/\{version\}/$HARBOR_VERSION} -O /tmp/harbor-offline-installer.tgz && tar xzf /tmp/harbor-offline-installer.tgz -C $HARBOR_HOME && cd $HARBOR_HOME && ./install.sh 2>&1" || { log_error "Deploy failed"; exit 1; }
audit_success "DEPLOY" "Harbor $HARBOR_VERSION deployed"
