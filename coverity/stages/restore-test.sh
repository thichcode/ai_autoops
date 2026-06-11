#!/bin/bash
# restore-test.sh — Restore Coverity from Backup Exec to staging & verify
set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

audit_started "RESTORE_TEST" "Restoring Coverity to staging"

source "$SCRIPT_DIR/config/staging.cfg"
STG_HOST="$COV_HOST"

REPORT_DIR="${BACKUP_BASE}/reports"
REPORT_FILE="${REPORT_DIR}/restore-test-coverity-${ENV}-$(date +%Y%m%d-%H%M%S).md"
mkdir -p "$REPORT_DIR"

TEST_ID="RESTORE-COV-$(date +%Y%m%d-%H%M%S)"
TEST_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OVERALL_STATUS="PASSED"
declare -a TEST_RESULTS=()

run_test() {
    local num="$1" name="$2" expected="$3" cmd="$4"
    local status="FAIL" actual=""
    start_time=$(date +%s%N)
    actual=$(eval "$cmd" 2>/dev/null || echo "ERROR")
    end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    if [[ "$actual" == "PASS" ]]; then
        status="PASS"; echo "    Status:   ✅ PASS  (${duration_ms}ms)"
    else
        OVERALL_STATUS="FAILED"; echo "    Status:   ❌ FAIL  (${duration_ms}ms)"
    fi
    TEST_RESULTS+=("{\"testNo\":$num,\"name\":\"$name\",\"expected\":\"$expected\",\"actual\":\"$actual\",\"status\":\"$status\",\"durationMs\":$duration_ms}")
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     RESTORE TEST REPORT — Coverity $ENV                ║"
echo "║     $TEST_ID                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo "  Date: $TEST_DATE | Restore: Backup Exec -> $STG_HOST"

echo "--------------------------------------------------------------"
echo "  PHASE 1: Backup Exec Restore"
echo "--------------------------------------------------------------"
read -rp "  Enter backup date (YYYY-MM-DD, empty=latest): " BACKUP_DATE
RESTORE_DATE_ARG=""; [[ -n "$BACKUP_DATE" ]] && RESTORE_DATE_ARG="-BackupDate '$BACKUP_DATE'"
if pwsh -Command ". '$PROJECT_ROOT/shared/lib/backup-exec-api.ps1'; Start-BERestore -JobName 'Coverity-${ENV}-Daily' -RestorePath '$STG_HOST' $RESTORE_DATE_ARG" 2>/dev/null; then
    echo "  ✅ Restore completed"; sleep 20
else
    read -rp "  Restore done? (yes/no): " c; [[ "$c" != "yes" ]] && { audit_failure "RESTORE_TEST" "Aborted"; return 1; }
fi

echo "--------------------------------------------------------------"
echo "  PHASE 2: Smoke Tests"
echo "--------------------------------------------------------------"
SECONDS=0
run_test 1 "Host reachable"     "ping OK"   "ping -c 2 -W 3 $STG_HOST &>/dev/null && echo 'PASS' || echo 'FAIL'"
run_test 2 "Service active"     "active"    "ssh_run '$STG_HOST' 'systemctl is-active $COV_SERVICE' 2>/dev/null | grep -q 'active' && echo 'PASS' || echo 'FAIL'"
run_test 3 "Web UI accessible"  "HTTP 200"  "curl -s -o /dev/null -w '%{http_code}' 'http://$STG_HOST:$COV_WEB_PORT' 2>/dev/null | grep -q '200' && echo 'PASS' || echo 'FAIL'"
TEST_DURATION=$SECONDS

TOTAL_TESTS=3; PASS_COUNT=$(printf '%s' "${TEST_RESULTS[@]}" | grep -c '"PASS"')
echo "  Verdict: $OVERALL_STATUS"
audit_record "RESTORE_TEST" "$OVERALL_STATUS" "$PASS_COUNT/$TOTAL_TESTS passed"
