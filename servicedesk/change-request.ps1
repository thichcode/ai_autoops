#!/usr/bin/env pwsh
param([string]$Env="prod", [string]$Action="patch")
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
. "$ProjectRoot/shared/lib/log.ps1"
. "$ProjectRoot/shared/lib/audit.ps1"
. "$ProjectRoot/shared/lib/servicedesk-api.ps1"
. "$ScriptDir/config/shared.cfg"
. "$ScriptDir/config/$Env.cfg"

$crBody = @{
    subject           = "Change Request: ServiceDesk $Action on $Env"
    description       = "Automated $Action pipeline for ServiceDesk Plus"
    category          = "Application Patching"
    priority          = "P3"
    planned_start     = (Get-Date).AddHours(1).ToString("yyyy-MM-ddTHH:mm:ss")
    planned_end       = (Get-Date).AddHours(4).ToString("yyyy-MM-ddTHH:mm:ss")
    impacted_services = "ServiceDesk Plus"
    risk_level        = "Medium"
    justification     = "Automated $Action per pipeline schedule"
    change_coordinator = "infra-team"
} | ConvertTo-Json
New-SDChangeRequest -Template $crBody
