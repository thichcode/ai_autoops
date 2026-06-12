#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$SD/config/staging.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "RESTORE_TEST" "Restoring Harbor to staging"
STG_NODE="$HARBOR_NODE"; REPORT_FILE="${BACKUP_BASE}/reports/restore-test-harbor-${ENV}-$(date +%Y%m%d-%H%M%S).md"; mkdir -p "${BACKUP_BASE}/reports"
OVERALL_STATUS="PASSED"
echo "--- PHASE 1: Backup Exec Restore ---"
read -rp "Backup date (YYYY-MM-DD, empty=latest): " BD
pwsh -Command ". '$PR/shared/lib/backup-exec-api.ps1'; Start-BERestore -JobName 'Harbor-${Env}-Daily' -RestorePath '$STG_NODE' $([[ -n \"$BD\" ]] && echo '-BackupDate $BD')" 2>/dev/null && sleep 30 || { read -rp "Done? (yes/no): " c; [[ "$c" != "yes" ]] && { audit_failure "RESTORE_TEST" "Aborted"; exit 1; }; }
echo "--- PHASE 2: Smoke Tests ---"; P=0; T=4
ping -c 2 "$STG_NODE" &>/dev/null && { echo "  ✅ 1. Reachable PASS"; P=$((P+1)); } || { echo "  ❌ 1. Reachable FAIL"; OVERALL_STATUS="FAILED"; }
ssh "$STG_NODE" "docker ps --format '{{.Names}}' 2>/dev/null | grep -q harbor-core" && { echo "  ✅ 2. Core container PASS"; P=$((P+1)); } || { echo "  ❌ 2. Core container FAIL"; OVERALL_STATUS="FAILED"; }
curl -sk "https://${STG_NODE}:${HARBOR_PORT}/api/v2.0/ping" &>/dev/null && { echo "  ✅ 3. API ping PASS"; P=$((P+1)); } || { echo "  ❌ 3. API ping FAIL"; OVERALL_STATUS="FAILED"; }
curl -sk -o /dev/null -w '%{http_code}' "https://${STG_NODE}:${HARBOR_PORT}" 2>/dev/null | grep -q 200 && { echo "  ✅ 4. HTTPS 200 PASS"; P=$((P+1)); } || { echo "  ❌ 4. HTTPS 200 FAIL"; OVERALL_STATUS="FAILED"; }
echo "# Harbor Restore Test" > "$REPORT_FILE"; echo "Verdict: $OVERALL_STATUS ($P/$T)" >> "$REPORT_FILE"
audit_record "RESTORE_TEST" "$OVERALL_STATUS" "$P/$T passed"; notify "Harbor restore-test $OVERALL_STATUS" ""
