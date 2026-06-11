#!/bin/bash
set -euo pipefail
ENV="${1:-prod}"; VERSION="${2:-2024.10}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
case "$ENV" in prod|staging) ;; *) echo "ERROR: Invalid environment: $ENV"; exit 1 ;; esac
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Invalid version format: $VERSION (expected x.y.z or x.y)"
    exit 1
fi
sed -i "s/BD_VERSION=.*/BD_VERSION=\"$VERSION\"/" "$SCRIPT_DIR/config/$ENV.cfg"
log_info "Patch started: $ENV -> $VERSION"
audit_started "PATCH" "Patching $ENV to $VERSION"
exec "$SCRIPT_DIR/pipeline.sh" patch "$ENV"
