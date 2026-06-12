#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$SD/config/staging.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "RESTORE_TEST" "Restoring Keycloak to staging"
STG_NODE="${KC_NODES[0]}"; STG_DB="$KC_DB_HOST"
REPORT_FILE="${BACKUP_BASE}/reports/restore-test-kc-${ENV}-$(date +%Y%m%d-%H%M%S).md"; mkdir -p "${BACKUP_BASE}/reports"; OVERALL_STATUS="PASSED"
echo "--- PHASE 1: Backup Exec Restore ---"
read -rp "Backup date: " BD
pwsh -Command ". '$PR/shared/lib/backup-exec-api.ps1'; Start-BERestore -JobName 'Keycloak-${Env}-Daily' -RestorePath '$STG_NODE' $([[ -n \"$BD\" ]] && echo '-BackupDate $BD')" 2>/dev/null && sleep 30 || { read -rp "Done? (yes/no): " c; [[ "$c" != "yes" ]] && { audit_failure "RESTORE_TEST" "Aborted"; exit 1; }; }
echo "--- PHASE 2: Smoke Tests ---"; P=0; T=4
ping -c 2 "$STG_NODE" &>/dev/null && { echo "  ✅ 1. Reachable PASS"; P=$((P+1)); } || { echo "  ❌ 1. Reachable FAIL"; OVERALL_STATUS="FAILED"; }
ssh "$STG_NODE" "systemctl is-active $KC_SERVICE" 2>/dev/null | grep -q active && { echo "  ✅ 2. Service PASS"; P=$((P+1)); } || { echo "  ❌ 2. Service FAIL"; OVERALL_STATUS="FAILED"; }
curl -sk "https://${STG_NODE}:${KC_PORT}/realms/master/.well-known/openid-configuration" 2>/dev/null | grep -q 'issuer' && { echo "  ✅ 3. OIDC PASS"; P=$((P+1)); } || { echo "  ❌ 3. OIDC FAIL"; OVERALL_STATUS="FAILED"; }
ssh "$STG_DB" "pg_isready -q" 2>/dev/null && { echo "  ✅ 4. DB PASS"; P=$((P+1)); } || { echo "  ❌ 4. DB FAIL"; OVERALL_STATUS="FAILED"; }
echo "# Keycloak Restore Test" > "$REPORT_FILE"; echo "Verdict: $OVERALL_STATUS ($P/$T)" >> "$REPORT_FILE"
audit_record "RESTORE_TEST" "$OVERALL_STATUS" "$P/$T passed"; notify "Keycloak restore-test $OVERALL_STATUS"
