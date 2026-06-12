#!/bin/bash
set -euo pipefail; ENV="$1"; NODE="${CURRENT_NODE:-${MINIO_NODES[0]}}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "MAINT" "Stopping MinIO on $NODE"
ADDR="${NODE%:*}"; ssh_run "$ADDR" "systemctl stop $MINIO_SERVICE" || true; sleep 5
audit_success "MAINT" "MinIO stopped on $NODE"
