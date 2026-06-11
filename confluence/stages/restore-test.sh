#!/bin/bash
# restore-test.sh — Restore Confluence from Backup Exec to staging + smoke tests
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

audit_started "RESTORE_TEST" "Restoring Confluence to staging"
source "$SCRIPT_DIR/config/staging.cfg"
STG_NODE="${CONF_NODES[0]}"; STG_DB="${DB_HOSTS[0]}"

REPORT_DIR="${BACKUP_BASE}/reports"; mkdir -p "$REPORT_DIR"
REPORT_FILE="${REPORT_DIR}/restore-test-confluence-${ENV}-$(date +%Y%m%d-%H%M%S).md"
TEST_ID="RESTORE-CONF-$(date +%Y%m%d-%H%M%S)"; TEST_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
OVERALL_STATUS="PASSED"; declare -a TEST_RESULTS=()

run_test() {
    local num="$1" name="$2" expected="$3" cmd="$4"
    local status="FAIL" actual=""
    local start=$(date +%s%N)
    actual=$(eval "$cmd" 2>/dev/null || echo "ERROR")
    local end=$(date +%s%N); local dur=$(( (end-start)/1000000 ))
    if [[ "$actual" == "PASS" ]]; then status="PASS"; echo "    ✅ PASS (${dur}ms)"
    else OVERALL_STATUS="FAILED"; echo "    ❌ FAIL (${dur}ms)"; fi
    TEST_RESULTS+=("{\"testNo\":$num,\"name\":\"$name\",\"expected\":\"$expected\",\"actual\":\"$actual\",\"status\":\"$status\",\"durationMs\":$dur}")
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     RESTORE TEST REPORT — Confluence $ENV               ║"
echo "╚══════════════════════════════════════════════════════════════╝"

echo "--- PHASE 1: Backup Exec Restore ---"
read -rp "  Backup date (YYYY-MM-DD, empty=latest): " BACKUP_DATE
RESTORE_ARG=""; [[ -n "$BACKUP_DATE" ]] && RESTORE_ARG="-BackupDate '$BACKUP_DATE'"
if pwsh -Command ". '$PROJECT_ROOT/shared/lib/backup-exec-api.ps1'; Start-BERestore -JobName 'Confluence-${ENV}-Daily' -RestorePath '$STG_NODE' $RESTORE_ARG" 2>/dev/null; then
    echo "  ✅ Restore completed"; sleep 30
else
    read -rp "  Restore done? (yes/no): " c; [[ "$c" != "yes" ]] && { audit_failure "RESTORE_TEST" "Aborted"; return 1; }
fi

echo "--- PHASE 2: Smoke Tests ---"
SECONDS=0
run_test 1 "Node reachable"   "ping OK"   "ping -c 2 -W 3 $STG_NODE &>/dev/null && echo PASS || echo FAIL"
run_test 2 "Service active"   "active"    "ssh_run '$STG_NODE' 'systemctl is-active $CONF_SERVICE' 2>/dev/null | grep -q active && echo PASS || echo FAIL"
run_test 3 "HTTP status"      "HTTP 200"  "curl -s -o /dev/null -w '%{http_code}' 'http://$STG_NODE:8090/status' 2>/dev/null | grep -q 200 && echo PASS || echo FAIL"
run_test 4 "DB reachable"     "pg_isready" "ssh_run '$STG_DB' 'pg_isready -q' 2>/dev/null && echo PASS || echo FAIL"
TEST_DURATION=$SECONDS

TOTAL_TESTS=4; PASS_COUNT=$(printf '%s' "${TEST_RESULTS[@]}" | grep -c 'PASS' || echo 0)
cat > "$REPORT_FILE" <<EOF
# Restore Test Report — Confluence $ENV
| Test ID | $TEST_ID | Date | $TEST_DATE | Backup | ${BACKUP_DATE:-latest} |
|---------|----------|------|----------|--------|----------------------|
| Staging App | $STG_NODE | Staging DB | $STG_DB | Verdict | $OVERALL_STATUS |
EOF
audit_record "RESTORE_TEST" "$OVERALL_STATUS" "$PASS_COUNT/$TOTAL_TESTS passed — report: $REPORT_FILE"
notify "Confluence restore-test $OVERALL_STATUS" "Report: $REPORT_FILE"
