#!/bin/bash
# deploy.sh — Upgrade GitLab package on app node (rolling)
set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

NODE="${CURRENT_NODE:?CURRENT_NODE not set}"
audit_started "DEPLOY" "Upgrading GitLab to $GITLAB_VERSION on $NODE"

if [[ "$GITLAB_EDITION" == "ee" ]]; then
    PKG_URL="https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/focal/gitlab-ee_${GITLAB_VERSION}_amd64.deb"
else
    PKG_URL="https://packages.gitlab.com/gitlab/gitlab-ce/packages/ubuntu/focal/gitlab-ce_${GITLAB_VERSION}_amd64.deb"
fi

log_info "Downloading GitLab $GITLAB_VERSION on $NODE"
ssh_run "$NODE" "wget -q $PKG_URL -O /tmp/gitlab-${GITLAB_VERSION}.deb"

log_info "Installing GitLab $GITLAB_VERSION on $NODE"
ssh_run "$NODE" "dpkg -i /tmp/gitlab-${GITLAB_VERSION}.deb"

# Run migrations only on the first node (DB schema migration once)
if [[ "$NODE" == "${GITLAB_APP_NODES[0]}" ]]; then
    log_info "Running DB migrations on $NODE (first node)"
    ssh_run "$NODE" "gitlab-rake db:migrate"
fi

log_info "Reconfiguring GitLab on $NODE"
ssh_run "$NODE" "gitlab-ctl reconfigure"

audit_success "DEPLOY" "GitLab $GITLAB_VERSION deployed on $NODE"
