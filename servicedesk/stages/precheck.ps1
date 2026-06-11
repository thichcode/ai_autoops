#!/usr/bin/env pwsh
param([string]$Env, [string]$Action)
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ProjectRoot = Split-Path -Parent $ScriptDir
. "$ProjectRoot/shared/lib/log.ps1"
. "$ProjectRoot/shared/lib/utils.ps1"
. "$ScriptDir/config/shared.cfg"
. "$ScriptDir/config/$Env.cfg"

Check-RBAC "sdplus-admins" $Env

foreach ($node in $SD_APP_NODES) {
    $result = Invoke-Command -ComputerName $node -ScriptBlock { param($d) Test-Path $d } -ArgumentList $SD_INSTALL_DIR -ErrorAction SilentlyContinue
    if ($result) { Write-Log INFO "App dir OK: $node" } else { Write-Log ERROR "App dir missing: $node"; exit 1 }
    $result = Invoke-Command -ComputerName $node -ScriptBlock { param($s) $(Get-Service $s -ErrorAction SilentlyContinue).Status } -ArgumentList $SD_SERVICE -ErrorAction SilentlyContinue
    if ($result -eq "Running") { Write-Log INFO "Service running: $node" } else { Write-Log WARN "Service not running: $node" }
}
# Check PostgreSQL DB (Linux)
$pgResult = Invoke-Command -ComputerName $SD_DB_HOST -ScriptBlock { pg_isready -q } -ErrorAction SilentlyContinue
if ($pgResult -eq $null) { Write-Log ERROR "PostgreSQL unreachable on $SD_DB_HOST"; exit 1 }
Write-Log INFO "All pre-checks passed"
