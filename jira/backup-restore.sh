#!/bin/bash
# backup-restore.sh — Manual backup / restore
# Usage: ./backup-restore.sh backup [env]
#        ./backup-restore.sh restore [env] [backup-path]

set -euo pipefail

ACTION="${1:-backup}"
ENV="${2:-prod}"
BACKUP_PATH="$3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

case "$ACTION" in
    backup)
        audit_started "MANUAL_BACKUP" "Manual backup triggered for $ENV"
        bash "$SCRIPT_DIR/stages/backup.sh" "$ENV"
        ;;
    restore)
        if [[ -z "$BACKUP_PATH" ]]; then
            log_error "Usage: $0 restore <env> <backup-path>"
            exit 1
        fi
        audit_started "MANUAL_RESTORE" "Manual restore from $BACKUP_PATH for $ENV"
        export JIRA_BACKUP_PATH="$BACKUP_PATH"
        bash "$SCRIPT_DIR/pipeline.sh" restore "$ENV"
        ;;
    *)
        echo "Usage: $0 {backup|restore} [env] [backup-path]"
        exit 1
        ;;
esac
