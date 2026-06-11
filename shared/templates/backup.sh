#!/bin/bash
# Template: backup stage — override in system stages/
set -euo pipefail
ENV="$1"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
log_warn "No custom backup script for this system — using default template (no-op)"
