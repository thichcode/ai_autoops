# rollback.ps1 — Generic rollback helpers

function Restore-Snapshot {
    param([string]$TargetPath, [string]$BackupPath)
    if (-not (Test-Path $BackupPath)) {
        Write-LogError "Backup path not found: $BackupPath"
        throw "Backup not found"
    }
    Write-LogWarn "ROLLBACK: Restoring $TargetPath from $BackupPath"
    $rollbackTag = "rollback-$(Get-Date -Format 'yyyyMMddHHmmss')"
    if (Test-Path $TargetPath) {
        Rename-Item -Path $TargetPath -NewName "$TargetPath.$rollbackTag"
    }
    Copy-Item -Path $BackupPath -Destination $TargetPath -Recurse -Force
    Audit-Success "ROLLBACK" "Restored $TargetPath from $BackupPath"
}
