#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "DEPLOY" "Deploying AWX $AWX_VERSION"
if [[ "$AWX_DEPLOY_METHOD" == "docker" ]]; then
    ssh_run "$AWX_NODE" "cd $AWX_HOME && wget -q https://github.com/ansible/awx/archive/${AWX_VERSION}.tar.gz -O /tmp/awx.tar.gz && tar xzf /tmp/awx.tar.gz -C /opt/ && cd /opt/awx-${AWX_VERSION} && ansible-playbook -i inventory install.yml 2>&1" || { log_error "AWX deploy failed"; exit 1; }
fi
audit_success "DEPLOY" "AWX $AWX_VERSION deployed"
