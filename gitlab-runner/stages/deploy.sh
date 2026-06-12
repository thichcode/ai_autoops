#!/bin/bash
set -euo pipefail; ENV="$1"; NODE="${CURRENT_NODE:?}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "DEPLOY" "Updating runner binary on $NODE"
ssh_run "$NODE" "wget -q $RUNNER_DOWNLOAD_URL -O /usr/local/bin/gitlab-runner && chmod +x /usr/local/bin/gitlab-runner && gitlab-runner --version" || { log_error "Runner update failed on $NODE"; exit 1; }
audit_success "DEPLOY" "Runner updated on $NODE"
