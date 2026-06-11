#!/usr/bin/env pwsh
param([string]$Env, [string]$Action)
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ProjectRoot = Split-Path -Parent $ScriptDir
. "$ProjectRoot/shared/lib/log.ps1"
. "$ProjectRoot/shared/lib/audit.ps1"
. "$ProjectRoot/shared/lib/backup-exec-api.ps1"
. "$ProjectRoot/shared/lib/utils.ps1"
. "$ScriptDir/config/shared.cfg"
. "$ScriptDir/config/$Env.cfg"
. "$ScriptDir/config/staging.cfg"

Audit-Started "RESTORE_TEST" "Restoring ServiceDesk to staging" $Env
$stgNode = $SD_APP_NODES[0]; $stgDb = $SD_DB_HOST
$ReportDir = Join-Path $env:BACKUP_BASE "reports"; New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
$TestId = "RESTORE-SDP-$(Get-Date -Format yyyyMMddHHmmss)"
$TestDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$Results = @(); $OverallStatus = "PASSED"

Write-Host "--- PHASE 1: Backup Exec Restore ---"
$backupDate = Read-Host "Backup date (YYYY-MM-DD, empty=latest)"
$restoreArgs = @{JobName = "ServiceDesk-${Env}-Daily"; RestorePath = $stgNode}
if ($backupDate) { $restoreArgs.BackupDate = $backupDate }
try {
    Start-BERestore @restoreArgs -ErrorAction Stop
    Start-Sleep -Seconds 30
} catch {
    $continue = Read-Host "Restore done? (yes/no)"
    if ($continue -ne "yes") { Audit-Failure "RESTORE_TEST" "Aborted" $Env; return }
}

Write-Host "--- PHASE 2: Smoke Tests ---"
$sw = [System.Diagnostics.Stopwatch]::StartNew()

$tests = @(
    @{num=1; name="Node reachable"; cmd="ping -n 2 -w 3000 $stgNode 2>&1 | Select-String 'TTL'"}
    @{num=2; name="Service running"; cmd="Invoke-Command -ComputerName $stgNode -ScriptBlock { (Get-Service $using:SD_SERVICE).Status -eq 'Running' } -ErrorAction SilentlyContinue"}
    @{num=3; name="HTTP available"; cmd="Invoke-WebRequest -Uri 'http://${stgNode}:${SD_WEB_PORT}' -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue; `$? ? 'PASS' : 'FAIL'"}
    @{num=4; name="DB reachable"; cmd="Invoke-Command -ComputerName $stgDb -ScriptBlock { pg_isready -q } -ErrorAction SilentlyContinue"}
)

foreach ($t in $tests) {
    $tsw = [System.Diagnostics.Stopwatch]::StartNew()
    try { $actual = if (Invoke-Expression $t.cmd) { "PASS" } else { "FAIL" } } catch { $actual = "FAIL" }
    $tsw.Stop()
    if ($actual -eq "PASS") { Write-Host "    ✅ Test $($t.num): $($t.name) PASS ($($tsw.ElapsedMilliseconds)ms)" }
    else { $OverallStatus = "FAILED"; Write-Host "    ❌ Test $($t.num): $($t.name) FAIL ($($tsw.ElapsedMilliseconds)ms)" }
    $Results += [PSCustomObject]@{TestNo=$t.num; Name=$t.name; Status=$actual; DurationMs=$tsw.ElapsedMilliseconds}
}
$sw.Stop()
$totalTests = $tests.Count; $passCount = ($Results | Where-Object Status -eq "PASS").Count
Audit-Record "RESTORE_TEST" $OverallStatus "$passCount/$totalTests passed" $Env
Notify "ServiceDesk restore-test $OverallStatus" "Test ID: $TestId, Duration: $($sw.Elapsed.TotalSeconds)s"
