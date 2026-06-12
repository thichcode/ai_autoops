#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$SD/config/staging.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "RESTORE_TEST" "Restoring Prometheus+Grafana to staging"
STG_P="$PROM_NODE"; STG_G="$GRAFANA_NODE"; STG_A="$ALERT_NODE"
REPORT_FILE="${BACKUP_BASE}/reports/restore-test-pg-${ENV}-$(date +%Y%m%d-%H%M%S).md"; mkdir -p "${BACKUP_BASE}/reports"; OVERALL_STATUS="PASSED"
echo "--- PHASE 1: Backup Exec Restore ---"
read -rp "Backup date (YYYY-MM-DD, empty=latest): " BD
pwsh -Command ". '$PR/shared/lib/backup-exec-api.ps1'; Start-BERestore -JobName 'PG-${Env}-Daily' -RestorePath '$STG_P' $([[ -n \"$BD\" ]] && echo '-BackupDate $BD')" 2>/dev/null && sleep 30 || { read -rp "Done? (yes/no): " c; [[ "$c" != "yes" ]] && { audit_failure "RESTORE_TEST" "Aborted"; exit 1; }; }
echo "--- PHASE 2: Smoke Tests ---"; P=0; T=5
for test in "1. Prometheus reachable:ping -c 2 $STG_P &>/dev/null" "2. Prometheus ready:curl -s http://${STG_P}:${PROM_PORT}/-/ready | grep -q Ready" "3. Grafana reachable:ping -c 2 $STG_G &>/dev/null" "4. Grafana health:curl -s http://${STG_G}:${GRAFANA_PORT}/api/health | grep -q ok" "5. Alertmanager reachable:ping -c 2 $STG_A &>/dev/null"; do
    N="${test%%:*}"; C="${test#*:}"; eval "$C" && { echo "  ✅ $N PASS"; P=$((P+1)); } || { echo "  ❌ $N FAIL"; OVERALL_STATUS="FAILED"; }
done
echo "# Prometheus+Grafana Restore Test" > "$REPORT_FILE"; echo "Verdict: $OVERALL_STATUS ($P/$T)" >> "$REPORT_FILE"
audit_record "RESTORE_TEST" "$OVERALL_STATUS" "$P/$T passed"; notify "PG restore-test $OVERALL_STATUS" ""
