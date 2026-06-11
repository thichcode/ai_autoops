#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg" "$SCRIPT_DIR/config/staging.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh" "$PROJECT_ROOT/shared/lib/utils.sh"
audit_started "RESTORE_TEST" "Restoring Jenkins to staging"
STG_NODE="$JENKINS_CONTROLLER"
REPORT_FILE="${BACKUP_BASE}/reports/restore-test-jenkins-${ENV}-$(date +%Y%m%d-%H%M%S).md"; mkdir -p "${BACKUP_BASE}/reports"
OVERALL_STATUS="PASSED"; declare -a TEST_RESULTS=()
run_test() { local num="$1" name="$2" cmd="$3"; local status="FAIL" actual; actual=$(eval "$cmd" 2>/dev/null || echo "ERROR"); [[ "$actual" == "PASS" ]] && status="PASS"; echo "    $([ "$status" == "PASS" ] && echo '✅' || echo '❌') $num. $name ($status)"; TEST_RESULTS+=("{\"testNo\":$num,\"name\":\"$name\",\"status\":\"$status\"}"); [[ "$status" == "FAIL" ]] && OVERALL_STATUS="FAILED"; }
echo "--- PHASE 1: Backup Exec Restore ---"
read -rp "  Backup date (YYYY-MM-DD, empty=latest): " BACKUP_DATE
pwsh -Command ". '$PROJECT_ROOT/shared/lib/backup-exec-api.ps1'; Start-BERestore -JobName 'Jenkins-${Env}-Daily' -RestorePath '$STG_NODE' $([[ -n "$BACKUP_DATE" ]] && echo "-BackupDate '$BACKUP_DATE'")" 2>/dev/null && sleep 30 || { read -rp "Done? (yes/no): " c; [[ "$c" != "yes" ]] && { audit_failure "RESTORE_TEST" "Aborted"; exit 1; }; }
run_test 1 "Node reachable"   "ping -c 2 -W 3 $STG_NODE &>/dev/null && echo PASS || echo FAIL"
run_test 2 "Service active"   "ssh_run '$STG_NODE' 'systemctl is-active $JENKINS_SERVICE' 2>/dev/null | grep -q active && echo PASS || echo FAIL"
run_test 3 "HTTP status"      "curl -s -o /dev/null -w '%{http_code}' 'http://${STG_NODE}:${JENKINS_PORT}' 2>/dev/null | grep -q 200 && echo PASS || echo FAIL"
run_test 4 "JENKINS_HOME OK"  "ssh_run '$STG_NODE' 'test -d $JENKINS_HOME/jobs && echo PASS || echo FAIL' 2>/dev/null || echo FAIL"
TOTAL=4; PASS=$(printf '%s' "${TEST_RESULTS[@]}" | grep -c '"PASS"' || echo 0)
echo "# Jenkins Restore Test" > "$REPORT_FILE"; echo "Verdict: $OVERALL_STATUS ($PASS/$TOTAL)" >> "$REPORT_FILE"
audit_record "RESTORE_TEST" "$OVERALL_STATUS" "$PASS/$TOTAL passed"
notify "Jenkins restore-test $OVERALL_STATUS" "Report: $REPORT_FILE"
