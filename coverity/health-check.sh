#!/bin/bash
set -euo pipefail
ENV="${1:-prod}"; SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"; source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"
echo "=== Coverity Health Check - $ENV ==="
echo -n "Service: "; ssh_run "$COV_HOST" "systemctl status $COV_SERVICE | head -5" 2>/dev/null || echo "FAILED"
echo -n "Web: "; curl -s -o /dev/null -w "HTTP %{http_code}\n" "http://$COV_HOST:$COV_WEB_PORT" 2>/dev/null || echo "unreachable"
