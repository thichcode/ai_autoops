#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$SD/config/staging.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "RESTORE_TEST" "Restoring AWX to staging"
STG_NODE="$AWX_NODE"; STG_DB="$AWX_DB_HOST"
REPORT_FILE="${BACKUP_BASE}/reports/restore-test-awx-${ENV}-$(date +%Y%m%d-%H%M%S).md"; mkdir -p "${BACKUP_BASE}/reports"; OVERALL_STATUS="PASSED"
echo "--- PHASE 1: Backup Exec Restore ---"
read -rp "Backup date (YYYY-MM-DD, empty=latest): " BD
pwsh -Command ". '$PR/shared/lib/backup-exec-api.ps1'; Start-BERestore -JobName 'AWX-${Env}-Daily' -RestorePath '$STG_NODE' $([[ -n \"$BD\" ]] && echo '-BackupDate $BD')" 2>/dev/null && sleep 30 || { read -rp "Done? (yes/no): " c; [[ "$c" != "yes" ]] && { audit_failure "RESTORE_TEST" "Aborted"; exit 1; }; }
echo "--- PHASE 2: Smoke Tests ---"; P=0; T=4
ping -c 2 "$STG_NODE" &>/dev/null && { echo "  ✅ 1. Reachable PASS"; P=$((P+1)); } || { echo "  ❌ 1. Reachable FAIL"; OVERALL_STATUS="FAILED"; }
if [[ "$AWX_DEPLOY_METHOD" == "docker" ]]; then
    ssh "$STG_NODE" "docker ps --format '{{.Names}}' 2>/dev/null | grep -q awx_task" && { echo "  ✅ 2. AWX container PASS"; P=$((P+1)); } || { echo "  ❌ 2. AWX container FAIL"; OVERALL_STATUS="FAILED"; }
else
    ssh "$STG_NODE" "systemctl is-active awx" 2>/dev/null | grep -q active && { echo "  ✅ 2. AWX service PASS"; P=$((P+1)); } || { echo "  ❌ 2. AWX service FAIL"; OVERALL_STATUS="FAILED"; }
fi
curl -sk "https://${STG_NODE}:${AWX_PORT}" -o /dev/null -w '%{http_code}' 2>/dev/null | grep -q 200 && { echo "  ✅ 3. HTTPS PASS"; P=$((P+1)); } || { echo "  ❌ 3. HTTPS FAIL"; OVERALL_STATUS="FAILED"; }
ssh "$STG_DB" "pg_isready -q" 2>/dev/null && { echo "  ✅ 4. DB reachable PASS"; P=$((P+1)); } || { echo "  ❌ 4. DB reachable FAIL"; OVERALL_STATUS="FAILED"; }
echo "# AWX Restore Test" > "$REPORT_FILE"; echo "Verdict: $OVERALL_STATUS ($P/$T)" >> "$REPORT_FILE"
audit_record "RESTORE_TEST" "$OVERALL_STATUS" "$P/$T passed"; notify "AWX restore-test $OVERALL_STATUS" ""
