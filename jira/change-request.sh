#!/bin/bash
# change-request.sh — ManageEngine SD+ change request management
# Usage: ./change-request.sh create|update|add-note [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/shared/lib/log.sh"

case "${1:-help}" in
    create)
        shift
        pwsh -File "$PROJECT_ROOT/shared/lib/servicedesk-api.ps1" \
            -Command "New-SDChangeRequest @{Title='$1'; Description='$2'; Priority='${3:-Medium}'}"
        ;;
    update)
        CR_ID="$2"
        STATUS="$3"
        pwsh -File "$PROJECT_ROOT/shared/lib/servicedesk-api.ps1" \
            -Command "Update-SDChangeRequest -CrId '$CR_ID' -Status '$STATUS'"
        ;;
    add-note)
        CR_ID="$2"
        NOTE="$3"
        pwsh -File "$PROJECT_ROOT/shared/lib/servicedesk-api.ps1" \
            -Command "Add-SDChangeNote -CrId '$CR_ID' -Note '$NOTE'"
        ;;
    *)
        echo "Usage: $0 {create|update|add-note} [args...]"
        echo "  create <title> <description> [priority]"
        echo "  update <cr-id> <status>"
        echo "  add-note <cr-id> <note-text>"
        exit 1
        ;;
esac
