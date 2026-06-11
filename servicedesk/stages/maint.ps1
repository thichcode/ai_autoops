#!/usr/bin/env pwsh
param([string]$Env, [string]$Action)
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ProjectRoot = Split-Path -Parent $ScriptDir
. "$ProjectRoot/shared/lib/log.ps1"
. "$ProjectRoot/shared/lib/audit.ps1"
. "$ScriptDir/config/shared.cfg"
. "$ScriptDir/config/$Env.cfg"

$node = $env:CURRENT_NODE
Audit-Started "MAINT" "Stopping ServiceDesk on $node" $Env
Invoke-Command -ComputerName $node -ScriptBlock { param($s) Stop-Service $s -Force; Start-Sleep 5 } -ArgumentList $SD_SERVICE -ErrorAction SilentlyContinue
Audit-Success "MAINT" "Service stopped on $node" $Env
