#!/bin/bash
set -euo pipefail
# audit.sh — ISO 27001 A.12.4 compliant audit trail
# Source after log.sh; requires log_info/log_error functions
# Usage: audit_record "ACTION" "STATUS" "DETAILS"

AUDIT_LOG=${AUDIT_LOG:-/var/log/ai_ops/audit.log}

audit_record() {
    local action="$1"
    local status="$2"
    local details="$3"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local user
    user=$(whoami)
    local host
    host=$(hostname)
    local pid=$$

    local entry
    entry=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "user": "$user",
  "host": "$host",
  "pid": $pid,
  "action": $(echo "$action" | jq -R -s '.'),
  "status": $(echo "$status" | jq -R -s '.'),
  "details": $(echo "$details" | jq -R -s '.')
}
EOF
)
    echo "$entry" >> "$AUDIT_LOG"
    log_info "AUDIT: $action - $status"
}

audit_success() { audit_record "$1" "SUCCESS" "$2"; }
audit_failure() { audit_record "$1" "FAILURE" "$2"; }
audit_started() { audit_record "$1" "STARTED" "$2"; }
