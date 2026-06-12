#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
BACKUP_TAG="minio-${ENV}-$(date +%Y%m%d%H%M%S)"; audit_started "BACKUP" "MinIO backup: $BACKUP_TAG"
FIRST="${MINIO_NODES[0]}"; ADDR="${FIRST%:*}"; PORT="${FIRST#*:}"
# mc mirror for bucket backup
ssh_run "$ADDR" "mc mirror --watch /data/minio ${MINIO_BACKUP_TARGET} 2>/dev/null &" || log_warn "mc mirror skipped"
# Config backup
ssh_run "$ADDR" "mc admin config export minio/ > ${BACKUP_BASE}/minio-config-${BACKUP_TAG}.txt" 2>/dev/null || true
# IAM policy backup
ssh_run "$ADDR" "mc admin policy export minio/ all > ${BACKUP_BASE}/minio-policies-${BACKUP_TAG}.json" 2>/dev/null || true
audit_success "BACKUP" "MinIO backup: $BACKUP_TAG"
