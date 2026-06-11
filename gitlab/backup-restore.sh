#!/bin/bash
# backup-restore.sh — Manual backup / restore for multi-node GitLab
# Usage: ./backup-restore.sh backup [env]
#        ./backup-restore.sh restore [env] [backup-file]
set -euo pipefail

ACTION="${1:-backup}"
ENV="${2:-prod}"
BACKUP_FILE="$3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

case "$ACTION" in
    backup)
        audit_started "MANUAL_BACKUP" "Manual GitLab backup for $ENV"
        bash "$SCRIPT_DIR/stages/backup.sh" "$ENV"
        ;;
    restore)
        if [[ -z "$BACKUP_FILE" ]]; then
            log_error "Usage: $0 restore <env> <backup-file>"
            echo "Restore steps (manual):"
            echo "  1. Stop app nodes: ./gitlab/pipeline.sh stop $ENV"
            echo "  2. Stop Sidekiq on all app nodes"
            echo "  3. Restore PG: gunzip -c <backup.sql.gz> | psql -U gitlab gitlabhq_production"
            echo "  4. Restore NFS data from NFS backup"
            echo "  5. Restart: ./gitlab/pipeline.sh start $ENV"
            exit 1
        fi
        audit_started "MANUAL_RESTORE" "Manual restore from $BACKUP_FILE for $ENV"
        echo "WARNING: Manual restore requires stopping ALL app nodes first."
        echo "Run: ./gitlab/pipeline.sh stop $ENV"
        ;;
    *)
        echo "Usage: $0 {backup|restore} [env] [backup-file]"
        exit 1
        ;;
esac
