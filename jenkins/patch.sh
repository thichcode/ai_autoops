#!/bin/bash
set -euo pipefail; cd "$(dirname "$0")"; exec bash pipeline.sh patch "${1:-prod}"
