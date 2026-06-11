#!/usr/bin/env pwsh
param([string]$Env, [string]$Action)
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ProjectRoot = Split-Path -Parent $ScriptDir
. "$ProjectRoot/shared/lib/log.ps1"
. "$ProjectRoot/shared/lib/audit.ps1"
. "$ScriptDir/config/shared.cfg"
. "$ScriptDir/config/$Env.cfg"

$node = $env:CURRENT_NODE
Audit-Started "ROLLBACK" "Rolling back ServiceDesk on $node" $Env
Invoke-Command -ComputerName $node -ScriptBlock { param($s) Stop-Service $s -Force; Start-Sleep 5 } -ArgumentList $SD_SERVICE -ErrorAction SilentlyContinue
# Restore app files from backup
$backupFile = Join-Path $SD_BACKUP_DIR "sdplus-app-${Env}-latest.zip"
Invoke-Command -ComputerName $node -ScriptBlock {
    param($bf, $id) 
    if (Test-Path $bf) { Expand-Archive -Path $bf -DestinationPath $id -Force }
    Start-Service $using:SD_SERVICE
} -ArgumentList $backupFile, $SD_INSTALL_DIR -ErrorAction SilentlyContinue
Audit-Success "ROLLBACK" "Rollback completed on $node" $Env
