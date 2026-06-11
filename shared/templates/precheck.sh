#!/bin/bash
# Template: precheck stage
set -euo pipefail
ENV="$1"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
log_info "Pre-check passed (default template)"
