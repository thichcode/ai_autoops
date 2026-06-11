#!/bin/bash
set -euo pipefail
ENV="$1"; NODE="${CURRENT_NODE:?}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

audit_started "DEPLOY" "Deploying Confluence $CONF_VERSION on $NODE"
BACKUP_DIR="${BACKUP_BASE}/confluence-${ENV}-backup"
ssh_run "$NODE" "cp -a $CONF_INSTALL_DIR $BACKUP_DIR" 2>/dev/null || true
DIST_URL="${CONF_DIST_URL/\{version\}/$CONF_VERSION}"
ssh_run "$NODE" "wget -q $DIST_URL -O /tmp/atlassian-confluence-${CONF_VERSION}.tar.gz && tar xzf /tmp/atlassian-confluence-${CONF_VERSION}.tar.gz -C /opt/atlassian/ && rm -f $CONF_INSTALL_DIR && ln -sf /opt/atlassian/confluence-${CONF_VERSION} $CONF_INSTALL_DIR"
audit_success "DEPLOY" "Confluence $CONF_VERSION deployed on $NODE"
