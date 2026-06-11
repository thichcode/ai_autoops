#!/bin/bash
set -euo pipefail; SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"; PROJECT_ROOT="$SCRIPT_DIR/.."; source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/${1:-prod}.cfg"
CR='{"subject":"Change Request: SonarQube '${2:-patch}' on '${1:-prod}'","description":"Automated","category":"Application Patching","priority":"P3","planned_start":"'$(date -d '+1hour' +%Y-%m-%dT%H:%M:%S)'","planned_end":"'$(date -d '+4hours' +%Y-%m-%dT%H:%M:%S)'","impacted_services":"SonarQube","risk_level":"Medium","justification":"Per schedule","change_coordinator":"infra-team"}'
pwsh -Command ". '$PROJECT_ROOT/shared/lib/servicedesk-api.ps1'; New-SDChangeRequest -Template '$CR'"
