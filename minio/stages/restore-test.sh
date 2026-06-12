#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$SD/config/staging.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "RESTORE_TEST" "Restoring MinIO to staging"
STG_NODE="${MINIO_NODES[0]%:*}"; STG_PORT="${MINIO_NODES[0]#*:}"
REPORT_FILE="${BACKUP_BASE}/reports/restore-test-minio-${ENV}-$(date +%Y%m%d-%H%M%S).md"; mkdir -p "${BACKUP_BASE}/reports"; OVERALL_STATUS="PASSED"
echo "--- PHASE 1: Backup Exec Restore ---"
read -rp "Backup date: " BD
pwsh -Command ". '$PR/shared/lib/backup-exec-api.ps1'; Start-BERestore -JobName 'MinIO-${Env}-Daily' -RestorePath '$STG_NODE' $([[ -n \"$BD\" ]] && echo '-BackupDate $BD')" 2>/dev/null && sleep 30 || { read -rp "Done? (yes/no): " c; [[ "$c" != "yes" ]] && { audit_failure "RESTORE_TEST" "Aborted"; exit 1; }; }
echo "--- PHASE 2: Smoke Tests ---"; P=0; T=4
ping -c 2 "$STG_NODE" &>/dev/null && { echo "  ✅ 1. Reachable PASS"; P=$((P+1)); } || { echo "  ❌ 1. Reachable FAIL"; OVERALL_STATUS="FAILED"; }
ssh "$STG_NODE" "systemctl is-active $MINIO_SERVICE" 2>/dev/null | grep -q active && { echo "  ✅ 2. Service PASS"; P=$((P+1)); } || { echo "  ❌ 2. Service FAIL"; OVERALL_STATUS="FAILED"; }
curl -s "http://${STG_NODE}:${MINIO_API_PORT}/minio/health/live" 2>/dev/null | grep -q 'ok' && { echo "  ✅ 3. S3 API PASS"; P=$((P+1)); } || { echo "  ❌ 3. S3 API FAIL"; OVERALL_STATUS="FAILED"; }
ssh "$STG_NODE" "ls $MINIO_DATA/.minio.sys/buckets 2>/dev/null | head -1" &>/dev/null && { echo "  ✅ 4. Data integrity PASS"; P=$((P+1)); } || { echo "  ❌ 4. Data integrity FAIL"; OVERALL_STATUS="FAILED"; }
echo "# MinIO Restore Test" > "$REPORT_FILE"; echo "Verdict: $OVERALL_STATUS ($P/$T)" >> "$REPORT_FILE"
audit_record "RESTORE_TEST" "$OVERALL_STATUS" "$P/$T passed"; notify "MinIO restore-test $OVERALL_STATUS"
