#!/bin/bash
# log.sh — Structured JSON logging for Bash scripts
# Usage: source log.sh; log_info "message"; log_error "message"

set -euo pipefail

LOG_LEVEL=${LOG_LEVEL:-INFO}
LOG_FILE=${LOG_FILE:-/var/log/ai_ops/operations.log}
LOG_DIR=$(dirname "$LOG_FILE")

declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [FATAL]=4)

_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local script_name
    script_name=$(basename "${BASH_SOURCE[2]:-$0}")
    local user
    user=$(whoami)
    local host
    host=$(hostname)

    if [[ ${LOG_LEVELS[$level]} -ge ${LOG_LEVELS[$LOG_LEVEL]} ]]; then
        _ensure_log_dir
        local log_entry
        log_entry=$(printf '{"timestamp":"%s","level":"%s","script":"%s","user":"%s","host":"%s","message":%s}' \
            "$timestamp" "$level" "$script_name" "$user" "$host" "$(echo "$message" | jq -R -s '.')")
        echo "$log_entry" >> "$LOG_FILE"
        if [[ "$level" == "ERROR" || "$level" == "FATAL" ]]; then
            echo "$log_entry" >&2
        else
            echo "$log_entry"
        fi
    fi
}

log_debug() { _log "DEBUG" "$1"; }
log_info()  { _log "INFO"  "$1"; }
log_warn()  { _log "WARN"  "$1"; }
log_error() { _log "ERROR" "$1"; }
log_fatal() { _log "FATAL" "$1"; }

_ensure_log_dir() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" || { echo "FATAL: Cannot create log directory $LOG_DIR"; return 1; }
    fi
}
