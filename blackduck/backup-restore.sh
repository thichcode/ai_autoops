#!/bin/bash
set -euo pipefail
ACTION="${1:-backup}"; ENV="${2:-prod}"
case "$ACTION" in backup) bash "$(dirname "$0")/stages/backup.sh" "$ENV" ;; *) echo "Usage: $0 backup [env]"; exit 1 ;; esac
