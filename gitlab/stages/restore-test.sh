#!/bin/bash
# restore-test.sh — Restore GitLab from Backup Exec to staging & run smoke tests
set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/notify.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

audit_started "RESTORE_TEST" "Restoring GitLab to staging for verification"

source "$SCRIPT_DIR/config/staging.cfg"
STG_APP="${GITLAB_APP_NODES[0]}"
STG_DB="${GITLAB_DB_HOST}"
STG_REDIS="${GITLAB_REDIS_HOST}"

REPORT_DIR="${BACKUP_BASE}/reports"
REPORT_FILE="${REPORT_DIR}/restore-test-gitlab-${ENV}-$(date +%Y%m%d-%H%M%S).md"
REPORT_JSON="${REPORT_DIR}/restore-test-gitlab-${ENV}-$(date +%Y%m%d-%H%M%S).json"
mkdir -p "$REPORT_DIR"

TEST_ID="RESTORE-GL-$(date +%Y%m%d-%H%M%S)"
TEST_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OVERALL_STATUS="PASSED"
declare -a TEST_RESULTS=()

run_test() {
    local num="$1" name="$2" expected="$3" cmd="$4"
    local status="FAIL" actual="" start_time end_time
    start_time=$(date +%s%N)
    echo ""; echo "  Smoke test $num: $name"; printf "    Expected: %s\n" "$expected"
    actual=$(eval "$cmd" 2>/dev/null || echo "ERROR")
    end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    if [[ "$actual" == "PASS" ]]; then
        status="PASS"; echo "    Status:   ✅ PASS  (${duration_ms}ms)"
    else
        OVERALL_STATUS="FAILED"; echo "    Status:   ❌ FAIL  (${duration_ms}ms)"
    fi
    TEST_RESULTS+=("$(cat <<EOF
  { "testNo": $num, "name": "$name", "expected": "$expected", "actual": "$actual", "status": "$status", "durationMs": $duration_ms }
EOF
)")
}

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     RESTORE TEST REPORT — GitLab $ENV                 ║"
echo "║     $TEST_ID                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Test ID:     $TEST_ID"
echo "  Date:        $TEST_DATE"
echo "  Environment: $ENV (Prod -> Staging)"
echo "  Restore:     Backup Exec -> Staging Server"
echo "  Staging:     $STG_APP / $STG_DB / $STG_REDIS"
echo ""

echo "--------------------------------------------------------------"
echo "  PHASE 1: Backup Exec Restore to Staging"
echo "--------------------------------------------------------------"
echo ""
echo "  Listing available backup sets for GitLab-${ENV}-Daily..."
pwsh -Command "
    . '$PROJECT_ROOT/shared/lib/backup-exec-api.ps1'
    Get-BEBackupSets -JobName 'GitLab-${ENV}-Daily'
" 2>/dev/null || echo "  (unable to list — will use latest)"
echo ""
read -rp "  Enter backup date to restore (YYYY-MM-DD, or empty for latest): " BACKUP_DATE
RESTORE_DATE_ARG=""
if [[ -n "$BACKUP_DATE" ]]; then
    RESTORE_DATE_ARG="-BackupDate '$BACKUP_DATE'"
    echo "  Selected: $BACKUP_DATE"
else
    echo "  Selected: Latest backup"
fi
echo ""

if pwsh -Command "
    . '$PROJECT_ROOT/shared/lib/backup-exec-api.ps1'
    Start-BERestore -JobName 'GitLab-${ENV}-Daily' -RestorePath '$STG_APP' $RESTORE_DATE_ARG
" 2>/dev/null; then
    echo "  STATUS: ✅ Backup Exec restore completed"
    sleep 30
else
    echo "  WARNING: BE automation unavailable. Manual: restore GitLab-${ENV} -> $STG_APP"
    read -rp "  Has restore completed? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "  STATUS: ⛔ ABORTED"; audit_failure "RESTORE_TEST" "User aborted"; return 1
    fi
fi
echo ""

echo "--------------------------------------------------------------"
echo "  PHASE 2: Smoke Tests (Automated)"
echo "--------------------------------------------------------------"
SECONDS=0

run_test 1 "App node reachable"       "ping OK"                "ping -c 2 -W 3 $STG_APP &>/dev/null && echo 'PASS' || echo 'FAIL'"
run_test 2 "GitLab services"          "all active"             "ssh_run '$STG_APP' 'gitlab-ctl status' 2>/dev/null | grep -qv 'down' && echo 'PASS' || echo 'FAIL'"
run_test 3 "PostgreSQL reachable"     "pg_isready"             "ssh_run '$STG_DB' 'pg_isready -U $GITLAB_DB_USER -d $GITLAB_DB_NAME' 2>/dev/null | grep -q 'accept' && echo 'PASS' || echo 'FAIL'"
run_test 4 "Redis reachable"          "PONG"                   "ssh_run '$STG_REDIS' 'redis-cli -p $GITLAB_REDIS_PORT PING' 2>/dev/null | grep -q 'PONG' && echo 'PASS' || echo 'FAIL'"
run_test 5 "GitLab health endpoint"   "HTTP 200"               "curl -s -o /dev/null -w '%{http_code}' 'https://$STG_APP/-/health' 2>/dev/null | grep -q '200' && echo 'PASS' || echo 'FAIL'"

TEST_DURATION=$SECONDS

echo "--------------------------------------------------------------"
echo "  PHASE 3: Generate Report"
echo "--------------------------------------------------------------"
TOTAL_TESTS=5
PASS_COUNT=$(printf '%s\n' "${TEST_RESULTS[@]}" | grep -c '"status": "PASS"' || echo 0)
FAIL_COUNT=$((TOTAL_TESTS - PASS_COUNT))
OVERALL_ICON="✅"; [[ "$OVERALL_STATUS" == "FAILED" ]] && OVERALL_ICON="❌"

cat > "$REPORT_JSON" <<EOF
{ "testId": "$TEST_ID", "date": "$TEST_DATE", "environment": "$ENV",
  "stagingApp": "$STG_APP", "stagingDb": "$STG_DB", "backupDate": "${BACKUP_DATE:-latest}",
  "tests": [ $(IFS=,; echo "${TEST_RESULTS[*]}") ],
  "summary": { "total": $TOTAL_TESTS, "passed": $PASS_COUNT, "failed": $FAIL_COUNT,
    "overallStatus": "$OVERALL_STATUS", "durationSeconds": $TEST_DURATION } }
EOF

cat > "$REPORT_FILE" <<REPORT_EOF
# Restore Test Report — GitLab $ENV

| Field | Value |
|-------|-------|
| Test ID | $TEST_ID |
| Date | $TEST_DATE |
| Environment | $ENV (Production -> Staging) |
| Restore Method | Backup Exec |
| Backup Date | ${BACKUP_DATE:-latest} |
| Staging App | $STG_APP |
| Staging DB | $STG_DB |
| Staging Redis | $STG_REDIS |

## Phase 1: Backup Exec Restore
Source: GitLab-${ENV}-Daily | Backup Set: ${BACKUP_DATE:-Latest} | Target: $STG_APP | Result: ✅ Completed

## Phase 2: Smoke Test Results
| # | Test Case | Expected | Actual | Status | Duration |
|---|-----------|----------|--------|--------|----------|
EOF
for result in "${TEST_RESULTS[@]}"; do
    n=$(echo "$result" | jq -r '.testNo'); nm=$(echo "$result" | jq -r '.name')
    ex=$(echo "$result" | jq -r '.expected'); ac=$(echo "$result" | jq -r '.actual')
    st=$(echo "$result" | jq -r '.status'); du=$(echo "$result" | jq -r '.durationMs')
    ic="✅"; [[ "$st" == "FAIL" ]] && ic="❌"
    echo "| $n | $nm | $ex | $ac | $ic $st | ${du}ms |" >> "$REPORT_FILE"
done
cat >> "$REPORT_FILE" <<REPORT_EOF

## Summary
| Total | Passed | Failed | Duration | Verdict |
|-------|--------|--------|----------|---------|
| $TOTAL_TESTS | $PASS_COUNT | $FAIL_COUNT | ${TEST_DURATION}s | $OVERALL_ICON $OVERALL_STATUS |

> Auto-generated — ISO 27001 A.12.4
REPORT_EOF

echo ""
echo "  Report: $REPORT_FILE"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Total: $TOTAL_TESTS  Passed: $PASS_COUNT  Failed: $FAIL_COUNT           ║"
echo "║  Verdict: $OVERALL_ICON  $OVERALL_STATUS                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"

if [[ "$OVERALL_STATUS" == "FAILED" ]]; then
    notify_failure "GitLab staging smoke tests FAILED" "Report: $REPORT_FILE"
    audit_failure "RESTORE_TEST" "$FAIL_COUNT/$TOTAL_TESTS failed"; return 1
fi
audit_success "RESTORE_TEST" "All $TOTAL_TESTS passed — report: $REPORT_FILE"
notify_success "GitLab staging verification PASSED" "Report: $REPORT_FILE"
