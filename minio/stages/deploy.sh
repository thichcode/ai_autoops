#!/bin/bash
set -euo pipefail; ENV="$1"; NODE="${CURRENT_NODE:-${MINIO_NODES[0]}}"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "DEPLOY" "Updating MinIO binary on $NODE"
ADDR="${NODE%:*}"; 
ssh_run "$ADDR" "wget -q $MINIO_DOWNLOAD_URL -O /usr/local/bin/minio && chmod +x /usr/local/bin/minio && wget -q $MINIO_CLIENT_URL -O /usr/local/bin/mc && chmod +x /usr/local/bin/mc && minio --version" || { log_error "MinIO update failed"; exit 1; }
audit_success "DEPLOY" "MinIO binary updated on $NODE"
