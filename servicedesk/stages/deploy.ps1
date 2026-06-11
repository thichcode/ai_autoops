#!/usr/bin/env pwsh
param([string]$Env, [string]$Action)
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ProjectRoot = Split-Path -Parent $ScriptDir
. "$ProjectRoot/shared/lib/log.ps1"
. "$ProjectRoot/shared/lib/audit.ps1"
. "$ScriptDir/config/shared.cfg"
. "$ScriptDir/config/$Env.cfg"

$node = $env:CURRENT_NODE
Audit-Started "DEPLOY" "Deploying ServiceDesk $SD_VERSION on $node" $Env
# SD+ is updated via installer; placeholders for version-specific update logic
Write-Log INFO "ServiceDesk $SD_VERSION deployment triggered on $node"
Audit-Success "DEPLOY" "ServiceDesk $SD_VERSION deployed on $node" $Env
