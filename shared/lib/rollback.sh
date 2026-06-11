#!/bin/bash
set -euo pipefail
# rollback.sh — Generic rollback helpers
# Usage: source rollback.sh; snapshot_restore "/opt/jira" "/backup/jira-pre-patch"

BACKUP_BASE=${BACKUP_BASE:-/backup}

snapshot_restore() {
    local target="$1"
    local backup_path="$2"
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup path not found: $backup_path"
        return 1
    fi
    log_warn "ROLLBACK: Restoring $target from $backup_path"
    if [[ -d "$target" ]]; then
        mv "$target" "${target}.rollback-$(date +%Y%m%d%H%M%S)"
    fi
    cp -a "$backup_path" "$target"
    log_info "ROLLBACK: $target restored successfully"
    audit_success "ROLLBACK" "Restored $target from $backup_path"
}

symlink_swap() {
    local current_link="$1"
    local backup_dir="$2"
    if [[ -L "$current_link" ]]; then
        rm "$current_link"
        ln -s "$backup_dir" "$current_link"
        log_info "ROLLBACK: Symlink $current_link -> $backup_dir"
    else
        log_error "ROLLBACK: $current_link is not a symlink"
        return 1
    fi
}
