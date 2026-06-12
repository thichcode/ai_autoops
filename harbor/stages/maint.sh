#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "MAINT" "Stopping Harbor"
ssh_run "$HARBOR_NODE" "cd $HARBOR_HOME && docker-compose down 2>/dev/null || docker compose down" || true; sleep 10
audit_success "MAINT" "Harbor stopped"
