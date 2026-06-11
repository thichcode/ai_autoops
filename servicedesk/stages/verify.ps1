#!/usr/bin/env pwsh
param([string]$Env, [string]$Action)
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ProjectRoot = Split-Path -Parent $ScriptDir
. "$ProjectRoot/shared/lib/log.ps1"
. "$ProjectRoot/shared/lib/audit.ps1"
. "$ScriptDir/config/shared.cfg"
. "$ScriptDir/config/$Env.cfg"

$node = $env:CURRENT_NODE
Audit-Started "VERIFY" "Verifying ServiceDesk on $node" $Env
Invoke-Command -ComputerName $node -ScriptBlock { param($s) Start-Service $s } -ArgumentList $SD_SERVICE -ErrorAction SilentlyContinue
Start-Sleep -Seconds 30
$status = Invoke-Command -ComputerName $node -ScriptBlock { param($s) (Get-Service $s).Status } -ArgumentList $SD_SERVICE -ErrorAction SilentlyContinue
if ($status -ne "Running") { Write-Log ERROR "Service not running: $status"; exit 1 }
# HTTP check
try {
    $resp = Invoke-WebRequest -Uri "http://${node}:${SD_WEB_PORT}" -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    Write-Log INFO "HTTP $($resp.StatusCode)"
} catch { Write-Log WARN "HTTP check failed: $_" }
Audit-Success "VERIFY" "Node verified: $node" $Env
