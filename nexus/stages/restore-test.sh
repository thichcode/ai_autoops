#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg" "$SCRIPT_DIR/config/staging.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "RESTORE_TEST" "Restoring Nexus to staging"
STG_NODE="$NEXUS_NODE"
REPORT_FILE="${BACKUP_BASE}/reports/restore-test-nexus-${ENV}-$(date +%Y%m%d-%H%M%S).md"; mkdir -p "${BACKUP_BASE}/reports"
OVERALL_STATUS="PASSED"
echo "--- PHASE 1: Backup Exec Restore ---"
read -rp "Backup date (YYYY-MM-DD, empty=latest): " BD
pwsh -Command ". '$PROJECT_ROOT/shared/lib/backup-exec-api.ps1'; Start-BERestore -JobName 'Nexus-${Env}-Daily' -RestorePath '$STG_NODE' $([[ -n \"$BD\" ]] && echo '-BackupDate $BD')" 2>/dev/null && sleep 30 || { read -rp "Done? (yes/no): " c; [[ "$c" != "yes" ]] && { audit_failure "RESTORE_TEST" "Aborted"; exit 1; }; }
echo "--- PHASE 2: Smoke Tests ---"
P=0; T=3
ping -c 2 "$STG_NODE" &>/dev/null && { echo "  ✅ 1. Node reachable PASS"; P=$((P+1)); } || { echo "  ❌ 1. Node reachable FAIL"; OVERALL_STATUS="FAILED"; }
ssh "$STG_NODE" "systemctl is-active $NEXUS_SERVICE" 2>/dev/null | grep -q active && { echo "  ✅ 2. Service active PASS"; P=$((P+1)); } || { echo "  ❌ 2. Service active FAIL"; OVERALL_STATUS="FAILED"; }
curl -s -o /dev/null -w '%{http_code}' "http://${STG_NODE}:${NEXUS_PORT}" 2>/dev/null | grep -q 200 && { echo "  ✅ 3. HTTP 200 PASS"; P=$((P+1)); } || { echo "  ❌ 3. HTTP 200 FAIL"; OVERALL_STATUS="FAILED"; }
echo "# Nexus Restore Test" > "$REPORT_FILE"; echo "Verdict: $OVERALL_STATUS ($P/$T)" >> "$REPORT_FILE"
audit_record "RESTORE_TEST" "$OVERALL_STATUS" "$P/$T passed"; notify "Nexus restore-test $OVERALL_STATUS" ""
