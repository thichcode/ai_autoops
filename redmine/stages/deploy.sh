#!/bin/bash
set -euo pipefail
ENV="$1"; NODE="${CURRENT_NODE:?}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "DEPLOY" "Deploying Redmine $REDMINE_VERSION on $NODE"
ssh_run "$NODE" "cp -a $REDMINE_HOME ${BACKUP_BASE}/redmine-previous/ 2>/dev/null; wget -q ${REDMINE_DOWNLOAD_URL/\{version\}/$REDMINE_VERSION} -O /tmp/redmine.tar.gz && tar xzf /tmp/redmine.tar.gz -C /opt/ && rm -f $REDMINE_HOME && ln -sf /opt/redmine-${REDMINE_VERSION} $REDMINE_HOME" || { log_error "Deploy failed"; exit 1; }
audit_success "DEPLOY" "Redmine $REDMINE_VERSION deployed on $NODE"
