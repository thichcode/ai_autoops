#!/bin/bash
# restore-test.sh — Restore from Backup Exec to staging & run smoke tests
# Generates formal test report for audit evidence (ISO 27001 A.12.4, ISO 20000 9.3)
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

audit_started "RESTORE_TEST" "Restoring to staging for verification"

source "$SCRIPT_DIR/config/staging.cfg"
STG_NODE="${JIRA_NODES[0]}"
STG_DB="${DB_HOSTS[0]}"

REPORT_DIR="${BACKUP_BASE}/reports"
REPORT_FILE="${REPORT_DIR}/restore-test-${ENV}-$(date +%Y%m%d-%H%M%S).md"
REPORT_JSON="${REPORT_DIR}/restore-test-${ENV}-$(date +%Y%m%d-%H%M%S).json"
mkdir -p "$REPORT_DIR"

TEST_ID="RESTORE-$(date +%Y%m%d-%H%M%S)"
TEST_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OVERALL_STATUS="PASSED"
declare -a TEST_RESULTS=()

# --- Helper: run a single test case ---
run_test() {
    local num="$1" name="$2" expected="$3"
    local cmd="$4"
    local status="FAIL"
    local actual=""
    local start_time
    local end_time
    start_time=$(date +%s%N)

    echo ""
    echo "  Smoke test $num: $name"
    printf "    Expected: %s\n" "$expected"

    actual=$(eval "$cmd" 2>/dev/null || echo "ERROR")
    end_time=$(date +%s%N)
    local duration_ms=$(( (end_time - start_time) / 1000000 ))

    if [[ "$actual" == "PASS" ]]; then
        status="PASS"
        echo "    Actual:   $actual"
        echo "    Status:   ✅ PASS  (${duration_ms}ms)"
    else
        OVERALL_STATUS="FAILED"
        echo "    Actual:   $actual"
        echo "    Status:   ❌ FAIL  (${duration_ms}ms)"
    fi

    TEST_RESULTS+=("$(cat <<EOF
  {
    "testNo": $num,
    "name": "$name",
    "expected": "$expected",
    "actual": "$actual",
    "status": "$status",
    "durationMs": $duration_ms
  }
EOF
)")
}

# ============================================================
# PHASE 1: Restore VM Snapshot to Staging (Manual)
# ============================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          RESTORE TEST REPORT — Jira $ENV              ║"
echo "║          $TEST_ID                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  Test ID:     $TEST_ID"
echo "  Date:        $TEST_DATE"
echo "  Environment: $ENV (Prod)"
echo "  Staging:     $STG_NODE / $STG_DB"
echo "  Restore:     Backup Exec -> Staging Server"
echo ""

echo "--------------------------------------------------------------"
echo "  PHASE 1: Restore from Backup Exec to Staging Server"
echo "--------------------------------------------------------------"
echo ""
echo "  Method:  Backup Exec restore job (BEMCLI)"
echo "  Source:  Backup Exec job Jira-${ENV}-Daily"
echo "  Target:  Staging — $STG_NODE (app), $STG_DB (DB)"
echo ""

echo "  Available backup sets for Jira-${ENV}-Daily:"
echo "  (fetching from Backup Exec...)"
echo ""
pwsh -Command "
    . '$PROJECT_ROOT/shared/lib/backup-exec-api.ps1'
    Get-BEBackupSets -JobName 'Jira-${ENV}-Daily'
" 2>/dev/null || echo "  (unable to list — will use latest)"
echo ""

read -rp "  Enter backup date to restore (YYYY-MM-DD, or leave empty for latest): " BACKUP_DATE
echo ""
RESTORE_DATE_ARG=""
if [[ -n "$BACKUP_DATE" ]]; then
    RESTORE_DATE_ARG="-BackupDate '$BACKUP_DATE'"
    echo "  Selected: $BACKUP_DATE"
else
    echo "  Selected: Latest backup"
fi
echo ""
echo "  Starting restore job on Backup Exec server..."

if pwsh -Command "
    . '$PROJECT_ROOT/shared/lib/backup-exec-api.ps1'
    Start-BERestore -JobName 'Jira-${ENV}-Daily' -RestorePath '$STG_NODE' $RESTORE_DATE_ARG
" 2>/dev/null; then
    echo "  STATUS: ✅ Backup Exec restore job completed"
    echo ""
    echo "  Waiting for services to start on staging..."
    sleep 30
else
    echo ""
    echo "  WARNING: Backup Exec automation unavailable."
    echo "  Manual steps required:"
    echo "    1. Open Backup Exec Console"
    [[ -n "$BACKUP_DATE" ]] && echo "    2. Select backup set: $BACKUP_DATE"
    echo "    3. Create restore job: Jira-${ENV} -> $STG_NODE"
    echo "    4. Wait for job to complete"
    echo ""
    read -rp "  Has restore completed? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo ""
        echo "  STATUS: ⛔ USER ABORTED"
        echo ""
        {
            echo "# Restore Test Report — ABORTED"
            echo "**Test ID:** $TEST_ID  **Date:** $TEST_DATE  **Status:** ABORTED"
            echo ""
            echo "Phase 1 (BE Restore) was aborted by the operator."
        } > "$REPORT_FILE"
        log_error "Restore to staging aborted by user"
        audit_failure "RESTORE_TEST" "User aborted"
        return 1
    fi
    echo "  STATUS: ✅ Manual restore confirmed"
fi

echo ""
PHASE1_DURATION=$SECONDS

# ============================================================
# PHASE 2: Automated Smoke Tests
# ============================================================
echo "--------------------------------------------------------------"
echo "  PHASE 2: Smoke Tests (Automated)"
echo "--------------------------------------------------------------"
echo ""

SECONDS=0

run_test 1 "Node reachability"  "ping reachable" \
    "ping -c 2 -W 3 $STG_NODE &>/dev/null && echo 'PASS' || echo 'FAIL'"

run_test 2 "Jira service status" "systemctl active" \
    "ssh_run '$STG_NODE' 'systemctl is-active jira' 2>/dev/null | grep -q 'active' && echo 'PASS' || echo 'FAIL'"

run_test 3 "HTTP health endpoint" "HTTP 200" \
    "curl -s -o /dev/null -w '%{http_code}' 'http://$STG_NODE:8080/status' 2>/dev/null | grep -q '200' && echo 'PASS' || echo 'FAIL'"

run_test 4 "Database connectivity" "SELECT 1 returns 1" \
    "ssh_run '$STG_DB' \"mysql -e 'SELECT 1' $STG_DB 2>/dev/null\" | grep -q '1' && echo 'PASS' || echo 'FAIL'"

run_test 5 "Jira login page" "HTTP 200 or 302" \
    "curl -s -o /dev/null -w '%{http_code}' 'http://$STG_NODE:8080/login.jsp' 2>/dev/null | grep -Eq '200|302' && echo 'PASS' || echo 'FAIL'"

run_test 6 "Project list API" "API responds with projects" \
    "curl -s -o /dev/null -w '%{http_code}' 'http://$STG_NODE:8080/rest/api/2/project' 2>/dev/null | grep -q '200' && echo 'PASS' || echo 'FAIL'"

TEST_DURATION=$SECONDS

# ============================================================
# PHASE 3: Generate Formal Report
# ============================================================
TOTAL_TESTS=6
PASS_COUNT=$(printf '%s\n' "${TEST_RESULTS[@]}" | grep -c '"status": "PASS"' || echo 0)
FAIL_COUNT=$((TOTAL_TESTS - PASS_COUNT))
OVERALL_ICON="✅"
OVERALL_COLOR="green"
if [[ "$OVERALL_STATUS" == "FAILED" ]]; then
    OVERALL_ICON="❌"
    OVERALL_COLOR="red"
fi

# Build JSON report
cat > "$REPORT_JSON" <<EOF
{
  "testId": "$TEST_ID",
  "date": "$TEST_DATE",
  "environment": "$ENV",
  "stagingNode": "$STG_NODE",
  "stagingDb": "$STG_DB",
  "phase1": "Backup Exec Restore to Staging",
  "backupDate": "${BACKUP_DATE:-latest}",
  "phase1Status": "COMPLETED",
  "tests": [
    $(IFS=,; echo "${TEST_RESULTS[*]}")
  ],
  "summary": {
    "total": $TOTAL_TESTS,
    "passed": $PASS_COUNT,
    "failed": $FAIL_COUNT,
    "overallStatus": "$OVERALL_STATUS",
    "durationSeconds": $TEST_DURATION
  }
}
EOF

# Build Markdown report
cat > "$REPORT_FILE" <<REPORT_EOF
# Restore Test Report — Jira $ENV

| Field | Value |
|-------|-------|
| **Test ID** | $TEST_ID |
| **Date** | $TEST_DATE |
| **Environment** | $ENV (Production → Staging) |
| **Restore Method** | Backup Exec (BEMCLI) |
| **Backup Date** | ${BACKUP_DATE:-latest} |
| **Staging Node** | $STG_NODE |
| **Staging DB** | $STG_DB |

---

## Phase 1: Backup Exec Restore to Staging

| Step | Detail |
|------|--------|
| Source BE Job | Jira-${ENV}-Daily |
| Backup Set | ${BACKUP_DATE:-Latest} |
| Target | Staging: $STG_NODE, $STG_DB |
| Method | Backup Exec restore via BEMCLI |
| Result | ✅ Completed successfully |

---

## Phase 2: Smoke Test Results

| # | Test Case | Expected | Actual | Status | Duration |
|---|-----------|----------|--------|--------|----------|
EOF

for result in "${TEST_RESULTS[@]}"; do
    local num name expected actual status duration
    num=$(echo "$result" | jq -r '.testNo')
    name=$(echo "$result" | jq -r '.name')
    expected=$(echo "$result" | jq -r '.expected')
    actual=$(echo "$result" | jq -r '.actual')
    status=$(echo "$result" | jq -r '.status')
    duration=$(echo "$result" | jq -r '.durationMs')
    local icon="✅"
    [[ "$status" == "FAIL" ]] && icon="❌"
    echo "| $num | $name | $expected | $actual | $icon $status | ${duration}ms |" >> "$REPORT_FILE"
done

cat >> "$REPORT_FILE" <<REPORT_EOF

---

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | $TOTAL_TESTS |
| Passed | $PASS_COUNT |
| Failed | $FAIL_COUNT |
| Duration | ${TEST_DURATION}s |
| **Overall Verdict** | $OVERALL_ICON **$OVERALL_STATUS** |

---

## Evidence

- **Test report (JSON):** $REPORT_JSON
- **Audit log:** $AUDIT_LOG
- **Operator:** $(whoami)
- **Host:** $(hostname)

> This report is auto-generated by the AI Ops pipeline as part of ISO 27001 A.12.4 compliance.
REPORT_EOF

# ============================================================
echo ""
echo "--------------------------------------------------------------"
echo "  PHASE 3: Test Report Generated"
echo "--------------------------------------------------------------"
echo ""
echo "  Report file: $REPORT_FILE"
echo "  JSON data:   $REPORT_JSON"
echo ""

# Show summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    TEST SUMMARY                             ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Total: $TOTAL_TESTS   Passed: $PASS_COUNT   Failed: $FAIL_COUNT        ║"
echo "║  Verdict: $OVERALL_ICON  $OVERALL_STATUS                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================
if [[ "$OVERALL_STATUS" == "FAILED" ]]; then
    log_error "Smoke tests FAILED on staging — see report: $REPORT_FILE"
    notify_failure "Staging smoke tests FAILED" "Report: $REPORT_FILE"
    audit_failure "RESTORE_TEST" "$FAIL_COUNT/$TOTAL_TESTS tests failed — report: $REPORT_FILE"
    return 1
fi

audit_success "RESTORE_TEST" "All $TOTAL_TESTS tests passed — report: $REPORT_FILE"
notify_success "Staging verification PASSED" "Report: $REPORT_FILE"
log_info "Restore test completed successfully"
