#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "DEPLOY" "Deploying Nexus $NEXUS_VERSION"
BACKUP_DIR="${BACKUP_BASE}/nexus-${ENV}-backup"
ssh_run "$NEXUS_NODE" "cp -a $NEXUS_HOME $BACKUP_DIR 2>/dev/null; wget -q ${NEXUS_DOWNLOAD_URL/\{version\}/$NEXUS_VERSION} -O /tmp/nexus.tar.gz && tar xzf /tmp/nexus.tar.gz -C /opt/ && rm -f $NEXUS_HOME && ln -sf /opt/nexus-${NEXUS_VERSION} $NEXUS_HOME" || { log_error "Deploy failed"; exit 1; }
audit_success "DEPLOY" "Nexus $NEXUS_VERSION deployed"
