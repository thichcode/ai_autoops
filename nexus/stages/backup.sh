#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
BACKUP_TAG="nexus-${ENV}-$(date +%Y%m%d%H%M%S)"
audit_started "BACKUP" "Nexus backup: $BACKUP_TAG"
# Nexus backup: blobs + DB (derby or PostgreSQL) + etc
ssh_run "$NEXUS_NODE" "systemctl stop $NEXUS_SERVICE" || true; sleep 10
ssh_run "$NEXUS_NODE" "tar czf ${BACKUP_BASE}/nexus-data-${BACKUP_TAG}.tgz -C $NEXUS_DATA . --exclude='cache' --exclude='tmp'" 2>/dev/null || log_warn "Data backup skipped"
ssh_run "$NEXUS_NODE" "systemctl start $NEXUS_SERVICE" || true; sleep 20
audit_success "BACKUP" "Nexus backup: $BACKUP_TAG"
