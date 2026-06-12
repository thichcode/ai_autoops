#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$SD/config/staging.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "RESTORE_TEST" "Restoring ELK to staging"
STG_ES="${ES_NODES[0]}"; STG_KB="$KB_NODE"; STG_LS="$LS_NODE"
REPORT_FILE="${BACKUP_BASE}/reports/restore-test-elk-${ENV}-$(date +%Y%m%d-%H%M%S).md"; mkdir -p "${BACKUP_BASE}/reports"
OVERALL_STATUS="PASSED"
echo "--- PHASE 1: Backup Exec Restore ---"
read -rp "Backup date (YYYY-MM-DD, empty=latest): " BD
pwsh -Command ". '$PR/shared/lib/backup-exec-api.ps1'; Start-BERestore -JobName 'ELK-${Env}-Daily' -RestorePath '$STG_ES' $([[ -n \"$BD\" ]] && echo '-BackupDate $BD')" 2>/dev/null && sleep 30 || { read -rp "Done? (yes/no): " c; [[ "$c" != "yes" ]] && { audit_failure "RESTORE_TEST" "Aborted"; exit 1; }; }
echo "--- PHASE 2: Smoke Tests ---"; P=0; T=5
ping -c 2 "$STG_ES" &>/dev/null && { echo "  ✅ 1. ES reachable PASS"; P=$((P+1)); } || { echo "  ❌ 1. ES reachable FAIL"; OVERALL_STATUS="FAILED"; }
curl -s "http://${STG_ES}:${ES_PORT}/_cluster/health" 2>/dev/null | grep -q 'status' && { echo "  ✅ 2. ES cluster PASS"; P=$((P+1)); } || { echo "  ❌ 2. ES cluster FAIL"; OVERALL_STATUS="FAILED"; }
ping -c 2 "$STG_KB" &>/dev/null && curl -s "http://${STG_KB}:${KB_PORT}/api/status" 2>/dev/null | grep -q 'version' && { echo "  ✅ 3. Kibana PASS"; P=$((P+1)); } || { echo "  ❌ 3. Kibana FAIL"; OVERALL_STATUS="FAILED"; }
ping -c 2 "$STG_LS" &>/dev/null && ssh "$STG_LS" "systemctl is-active $LS_SERVICE" 2>/dev/null | grep -q active && { echo "  ✅ 4. Logstash PASS"; P=$((P+1)); } || { echo "  ❌ 4. Logstash FAIL"; OVERALL_STATUS="FAILED"; }
curl -s "http://${STG_ES}:${ES_PORT}/_cat/indices" 2>/dev/null | head -5 | wc -l | grep -q '^[1-9]' && { echo "  ✅ 5. Indices exist PASS"; P=$((P+1)); } || { echo "  ❌ 5. Indices exist FAIL"; OVERALL_STATUS="FAILED"; }
echo "# ELK Restore Test" > "$REPORT_FILE"; echo "Verdict: $OVERALL_STATUS ($P/$T)" >> "$REPORT_FILE"
audit_record "RESTORE_TEST" "$OVERALL_STATUS" "$P/$T passed"; notify "ELK restore-test $OVERALL_STATUS" ""
