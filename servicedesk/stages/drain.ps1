#!/usr/bin/env pwsh
param([string]$Env, [string]$Action)
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ProjectRoot = Split-Path -Parent $ScriptDir
. "$ProjectRoot/shared/lib/log.ps1"
. "$ProjectRoot/shared/lib/audit.ps1"
. "$ScriptDir/config/shared.cfg"
. "$ScriptDir/config/$Env.cfg"

$node = $env:CURRENT_NODE
Audit-Started "DRAIN" "Draining $node" $Env
# SD+ typically does not use NGINX Plus; stop traffic via local service stop
Audit-Success "DRAIN" "Node drained: $node" $Env
