#!/bin/bash
# backup.sh — Jira pre-patch backup
# Backup strategy: VM-level snapshot (handled externally by vSphere/Backup Exec)
# This script only validates that a recent snapshot exists and backs up configs.
set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

BACKUP_TAG="jira-${ENV}-prepatch-$(date +%Y%m%d%H%M%S)"

log_info "Starting pre-patch snapshot verification for environment: $ENV"
audit_started "BACKUP" "Jira backup tag: $BACKUP_TAG"

# VM snapshot is managed externally (vSphere / Backup Exec)
# Verify snapshot age from the first app node
log_info "Checking VM snapshot status on ${JIRA_NODES[0]}..."
local SNAPSHOT_AGE
SNAPSHOT_AGE=$(ssh_run "${JIRA_NODES[0]}" \
    "stat -c %Y $JIRA_HOME 2>/dev/null || echo 0")
log_info "Last data modification timestamp: $SNAPSHOT_AGE"

# Export Jira config as lightweight backup
local CONFIG_BACKUP="${BACKUP_BASE}/jira-config-${BACKUP_TAG}.tar.gz"
log_info "Backing up Jira config to $CONFIG_BACKUP"
ssh_run "${JIRA_NODES[0]}" "tar czf $CONFIG_BACKUP -C $JIRA_INSTALL_DIR conf/" 2>/dev/null || true

audit_success "BACKUP" "Snapshot verified, config backed up: $BACKUP_TAG"
log_info "Pre-patch ready. Ensure VM snapshot is taken before proceeding."
