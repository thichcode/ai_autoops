#!/bin/bash
set -euo pipefail
# utils.sh — Common utilities: retry, checksum, SSH wrapper, RBAC check

BYPASS_RBAC=${BYPASS_RBAC:-false}
ALLOWED_GROUPS=${ALLOWED_GROUPS:-"jira-admins gitlab-ops coverity-admins blackduck-admins"}

check_rbac() {
    local system="$1"
    if [[ "$BYPASS_RBAC" == "true" ]]; then
        log_warn "RBAC check bypassed (BYPASS_RBAC=true)"
        return 0
    fi
    local user_groups
    user_groups=$(groups "$(whoami)" 2>/dev/null)
    for group in $ALLOWED_GROUPS; do
        if echo "$user_groups" | grep -qw "$group"; then
            log_info "RBAC: user $(whoami) authorized via group $group"
            return 0
        fi
    done
    log_fatal "RBAC: user $(whoami) not in allowed groups ($ALLOWED_GROUPS)"
    return 1
}

retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-5}"
    local attempt=1
    shift 2
    while [[ $attempt -le $max_attempts ]]; do
        if "$@"; then
            return 0
        fi
        log_warn "Command failed (attempt $attempt/$max_attempts): $*"
        sleep "$delay"
        ((attempt++))
    done
    log_error "Command failed after $max_attempts attempts: $*"
    return 1
}

checksum_verify() {
    local file="$1"
    local expected_hash="$2"
    local actual_hash
    actual_hash=$(sha256sum "$file" | awk '{print $1}')
    if [[ "$actual_hash" == "$expected_hash" ]]; then
        log_info "Checksum OK: $file"
        return 0
    else
        log_error "Checksum MISMATCH: $file (expected $expected_hash, got $actual_hash)"
        return 1
    fi
}

ssh_run() {
    local host="$1"
    local cmd="$2"
    local ssh_key="${3:-}"
    local ssh_opts=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
    if [[ -n "$ssh_key" ]]; then
        ssh_opts+=(-i "$ssh_key")
    fi
    ssh "${ssh_opts[@]}" "$host" "$cmd"
    return $?
}

scp_push() {
    local src="$1"
    local dest="$2"
    local ssh_key="${3:-}"
    local ssh_opts=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
    if [[ -n "$ssh_key" ]]; then
        ssh_opts+=(-i "$ssh_key")
    fi
    scp "${ssh_opts[@]}" "$src" "$dest"
    return $?
}
