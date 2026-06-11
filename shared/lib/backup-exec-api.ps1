# backup-exec-api.ps1 — Backup Exec BEMCLI wrapper (ISO 27001 A.12.3)
# Usage: . .\backup-exec-api.ps1; Start-BEBackup -JobName "Jira-Prod"

$Script:BEMCLIPath = "C:\Program Files\Veritas\Backup Exec\bemcli.exe"

function Test-BEMCLI {
    if (-not (Test-Path $Script:BEMCLIPath)) {
        throw "BEMCLI not found at $($Script:BEMCLIPath). Install Backup Exec Management Console."
    }
}

function Start-BEBackup {
    param([string]$JobName, [int]$TimeoutMinutes = 120)
    Test-BEMCLI
    Audit-Started "BE_BACKUP" "Starting backup job: $JobName"
    try {
        $result = & $Script:BEMCLIPath "job" "run" $JobName
        if ($LASTEXITCODE -ne 0) { throw "BEMCLI job run failed: $result" }
        Write-LogInfo "Backup job $JobName started. Waiting for completion..."
        $start = Get-Date
        while ($true) {
            $status = & $Script:BEMCLIPath "job" "status" $JobName
            if ($status -match "Completed|Success") {
                Audit-Success "BE_BACKUP" "Backup job $JobName completed"
                return $true
            }
            if ($status -match "Failed|Error") {
                throw "Backup job $JobName failed: $status"
            }
            if ((Get-Date) -gt $start.AddMinutes($TimeoutMinutes)) {
                throw "Backup job $JobName timed out after $TimeoutMinutes minutes"
            }
            Start-Sleep -Seconds 30
        }
    } catch {
        Audit-Failure "BE_BACKUP" "$_"
        throw
    }
}

function Get-BEBackupSets {
    param([string]$JobName)
    Test-BEMCLI
    Write-LogInfo "Fetching available backup sets for job: $JobName"
    $result = & $Script:BEMCLIPath "job" "listbackupsets" $JobName
    return $result
}

function Start-BERestore {
    param([string]$JobName, [string]$RestorePath, [string]$BackupDate = "")
    Test-BEMCLI
    Audit-Started "BE_RESTORE" "Starting restore from job: $JobName date=$BackupDate"
    try {
        $args = @("restore", "start", $JobName, "--path", $RestorePath)
        if ($BackupDate) {
            $args += "--backup-set"
            $args += $BackupDate
        }
        $result = & $Script:BEMCLIPath @args
        if ($LASTEXITCODE -ne 0) { throw "BEMCLI restore failed: $result" }
        Audit-Success "BE_RESTORE" "Restore job $JobName completed (date: $BackupDate)"
        return $true
    } catch {
        Audit-Failure "BE_RESTORE" "$_"
        throw
    }
}

function Test-BEJobStatus {
    param([string]$JobName)
    $status = & $Script:BEMCLIPath "job" "status" $JobName
    return $status
}
