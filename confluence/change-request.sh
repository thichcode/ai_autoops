#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/servicedesk-api.ps1"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/${1:-prod}.cfg"
ACTION="${2:-patch}"

CR_TEMPLATE=$(cat <<EOF
{
  "subject": "Change Request: Confluence $ACTION on ${1:-prod}",
  "description": "Automated $ACTION pipeline for Confluence",
  "category": "Application Patching",
  "priority": "P3",
  "planned_start": "$(date +%Y-%m-%dT%H:%M:%S -d '+1hour')",
  "planned_end": "$(date +%Y-%m-%dT%H:%M:%S -d '+4hours')",
  "impacted_services": "Confluence",
  "risk_level": "Medium",
  "justification": "Automated $ACTION per pipeline schedule",
  "change_coordinator": "infra-team"
}
EOF
)
pwsh -Command ". '$PROJECT_ROOT/shared/lib/servicedesk-api.ps1'; New-SDChangeRequest -Template '$CR_TEMPLATE'"
