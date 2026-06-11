#!/usr/bin/env pwsh
param([string]$Env, [string]$Action)
$ScriptDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ProjectRoot = Split-Path -Parent $ScriptDir
. "$ProjectRoot/shared/lib/log.ps1"
. "$ProjectRoot/shared/lib/audit.ps1"
. "$ScriptDir/config/shared.cfg"
. "$ScriptDir/config/$Env.cfg"

$BackupTag = "sdplus-${Env}-$(Get-Date -Format yyyyMMddHHmmss)"
Audit-Started "BACKUP" "ServiceDesk backup: $BackupTag" $Env

# DB backup (Linux PostgreSQL)
Invoke-Command -ComputerName $SD_DB_HOST -ScriptBlock {
    param($db, $user, $tag, $dir)
    $dump = Join-Path $dir "$tag.sql.gz"
    pg_dump -U $user $db | gzip > $dump
} -ArgumentList $SD_DB_NAME, $SD_DB_USER, $BackupTag, $SD_DB_BACKUP_DIR -ErrorAction SilentlyContinue

# App backup (Windows)
foreach ($node in $SD_APP_NODES) {
    Invoke-Command -ComputerName $node -ScriptBlock {
        param($dir, $installDir, $tag)
        $backupFile = Join-Path $dir "sdplus-app-${tag}.zip"
        if (Test-Path $installDir) { Compress-Archive -Path "$installDir\*" -DestinationPath $backupFile -Force }
    } -ArgumentList $SD_BACKUP_DIR, $SD_INSTALL_DIR, $BackupTag -ErrorAction SilentlyContinue
}
Audit-Success "BACKUP" "ServiceDesk backup: $BackupTag" $Env
