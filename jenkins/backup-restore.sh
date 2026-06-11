#!/bin/bash
set -euo pipefail; cd "$(dirname "$0")"; exec bash pipeline.sh backup "${1:-prod}"
