#!/bin/bash
# patch.sh — Entrypoint for GitLab patch update (multi-node rolling)
# Usage: ./patch.sh [env] [version]
set -euo pipefail

ENV="${1:-prod}"
VERSION="${2:-16.11.0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"

case "$ENV" in prod|staging) ;; *) echo "ERROR: Invalid environment: $ENV"; exit 1 ;; esac
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Invalid version format: $VERSION (expected x.y.z or x.y)"
    exit 1
fi

echo "=========================================="
echo "  GitLab Patch Update - Environment: $ENV"
echo "  Version: $VERSION"
echo "  App Nodes: ${GITLAB_APP_NODES[*]}"
echo "  DB: $GITLAB_DB_HOST"
echo "  Redis: $GITLAB_REDIS_HOST"
echo "  NFS: ${GITLAB_NFS_NODES[*]}"
echo "=========================================="

log_info "GitLab patch started: $ENV -> $VERSION"
audit_started "PATCH" "GitLab patch $ENV to $VERSION"

sed -i "s/GITLAB_VERSION=.*/GITLAB_VERSION=\"$VERSION\"/" "$SCRIPT_DIR/config/$ENV.cfg"

exec "$SCRIPT_DIR/pipeline.sh" patch "$ENV"
