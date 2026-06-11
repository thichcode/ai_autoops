#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg" "$SCRIPT_DIR/config/staging.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "RESTORE_TEST" "Restoring SonarQube to staging"
STG_NODE="$SONAR_NODE"; STG_DB="$SONAR_DB_HOST"
REPORT_FILE="${BACKUP_BASE}/reports/restore-test-sonar-${ENV}-$(date +%Y%m%d-%H%M%S).md"; mkdir -p "${BACKUP_BASE}/reports"
OVERALL_STATUS="PASSED"
echo "--- PHASE 1: Backup Exec Restore ---"
read -rp "Backup date (YYYY-MM-DD, empty=latest): " BD
pwsh -Command ". '$PROJECT_ROOT/shared/lib/backup-exec-api.ps1'; Start-BERestore -JobName 'SonarQube-${Env}-Daily' -RestorePath '$STG_NODE' $([[ -n \"$BD\" ]] && echo '-BackupDate $BD')" 2>/dev/null && sleep 30 || { read -rp "Done? (yes/no): " c; [[ "$c" != "yes" ]] && { audit_failure "RESTORE_TEST" "Aborted"; exit 1; }; }
echo "--- PHASE 2: Smoke Tests ---"
S=0; P=0; T=4
for t in "Node reachable:ping -c 2 $STG_NODE &>/dev/null" "Service active:ssh $STG_NODE 'systemctl is-active $SONAR_SERVICE' 2>/dev/null | grep -q active" "HTTP 200:curl -s -o /dev/null -w '%{http_code}' http://$STG_NODE:$SONAR_PORT 2>/dev/null | grep -q 200" "DB reachable:ssh $STG_DB 'pg_isready -q' 2>/dev/null"; do
    S=$((S+1)); nm="${t%%:*}"; cmd="${t#*:}"; eval "$cmd" && { echo "  ✅ $S. $nm PASS"; P=$((P+1)); } || { echo "  ❌ $S. $nm FAIL"; OVERALL_STATUS="FAILED"; }
done
echo "# SonarQube Restore Test" > "$REPORT_FILE"; echo "Verdict: $OVERALL_STATUS ($P/$T)" >> "$REPORT_FILE"
audit_record "RESTORE_TEST" "$OVERALL_STATUS" "$P/$T passed"; notify "SonarQube restore-test $OVERALL_STATUS" ""
