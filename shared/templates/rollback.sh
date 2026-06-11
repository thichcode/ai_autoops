#!/bin/bash
set -euo pipefail
ENV="$1"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
log_warn "No custom rollback script — using default template (no-op)"
