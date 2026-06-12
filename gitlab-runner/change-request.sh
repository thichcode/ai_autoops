#!/bin/bash
set -euo pipefail; S="$(cd "$(dirname "$0")" && pwd)"; P="$(cd "$S/.." && pwd)"; source "$S/config/shared.cfg" "$S/config/${1:-prod}.cfg"
CR='{"subject":"CR: GitLab Runner '${2:-patch}' '${1:-prod}'","description":"Auto","category":"Patching","priority":"P3","planned_start":"'$(date -d '+1hour' +%Y-%m-%dT%H:%M:%S)'","planned_end":"'$(date -d '+4hours' +%Y-%m-%dT%H:%M:%S)'","impacted_services":"GitLab Runner","risk_level":"Low","justification":"Per schedule","change_coordinator":"infra-team"}'
pwsh -Command ". '$P/shared/lib/servicedesk-api.ps1'; New-SDChangeRequest -Template '$CR'"
