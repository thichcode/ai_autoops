# audit.ps1 — ISO 27001 A.12.4 compliant audit trail
# Usage: . .\audit.ps1; Audit-Record -Action "backup" -Status "SUCCESS" -Details "completed"

$Script:AuditLog = if ($env:AUDIT_LOG) { $env:AUDIT_LOG } else { "C:\ProgramData\AI_Ops\Logs\audit.log" }

function Audit-Record {
    param([string]$Action, [string]$Status, [string]$Details)
    $timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    $user = ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $hostname = [Environment]::MachineName
    $processId = [Diagnostics.Process]::GetCurrentProcess().Id

    $entry = @{
        timestamp = $timestamp
        user      = $user
        host      = $hostname
        pid       = $processId
        action    = $Action
        status    = $Status
        details   = $Details
    }
    $logDir = Split-Path $Script:AuditLog -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force > $null }
    Add-Content -Path $Script:AuditLog -Value ($entry | ConvertTo-Json -Compress)
    Write-LogInfo "AUDIT: $Action - $Status"
}

function Audit-Success { Audit-Record -Action $args[0] -Status "SUCCESS" -Details $args[1] }
function Audit-Failure { Audit-Record -Action $args[0] -Status "FAILURE" -Details $args[1] }
function Audit-Started { Audit-Record -Action $args[0] -Status "STARTED" -Details $args[1] }
