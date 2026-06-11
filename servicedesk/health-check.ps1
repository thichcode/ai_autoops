#!/usr/bin/env pwsh
param([string]$Env="prod")
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
. "$ProjectRoot/shared/lib/log.ps1"
. "$ProjectRoot/shared/lib/notify.ps1"
. "$ScriptDir/config/shared.cfg"
. "$ScriptDir/config/$Env.cfg"

$reportLines = @("ServiceDesk Health Check ($(Get-Date)):`n")
foreach ($node in $SD_APP_NODES) {
    $status = Invoke-Command -ComputerName $node -ScriptBlock { param($s) (Get-Service $s -ErrorAction SilentlyContinue).Status } -ArgumentList $SD_SERVICE -ErrorAction SilentlyContinue
    if ($status) { $reportLines += "  $node - Service: $status" } else { $reportLines += "  $node - UNREACHABLE" }
}
$dbStatus = Invoke-Command -ComputerName $SD_DB_HOST -ScriptBlock { pg_isready -q ? "OK":"DOWN" } -ErrorAction SilentlyContinue
$reportLines += "  $($SD_DB_HOST) - PostgreSQL: $dbStatus"
$report = $reportLines -join "`n"
Write-Host $report
Notify "ServiceDesk health check" $report
