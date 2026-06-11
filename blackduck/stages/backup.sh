#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

audit_started "BACKUP" "BlackDuck backup on $BD_HOST"
ssh_run "$BD_HOST" "tar czf /backup/blackduck-${ENV}-$(date +%Y%m%d).tgz $BD_DATA_DIR" 2>/dev/null
audit_success "BACKUP" "BlackDuck data backed up"
