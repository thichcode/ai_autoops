# utils.ps1 — Common utilities: retry, checksum, RBAC check

$Script:BypassRBAC     = $env:BYPASS_RBAC -eq "true"
$Script:AllowedGroups  = @("jira-admins", "gitlab-ops", "coverity-admins")
$envGroups = [Environment]::GetEnvironmentVariable("ALLOWED_GROUPS")
if ($envGroups) { $Script:AllowedGroups = $envGroups -split '\s+' }

function Check-RBAC {
    param([string]$System)
    if ($Script:BypassRBAC) {
        Write-LogWarn "RBAC check bypassed"
        return $true
    }
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    foreach ($group in $Script:AllowedGroups) {
        if ($principal.IsInRole($group)) {
            Write-LogInfo "RBAC: $user authorized via group $group"
            return $true
        }
    }
    Write-LogFatal "RBAC: $user not in allowed groups ($($Script:AllowedGroups -join ','))"
    return $false
}

function Invoke-Retry {
    param([ScriptBlock]$ScriptBlock, [int]$MaxAttempts = 3, [int]$DelaySeconds = 5)
    $attempt = 1
    while ($attempt -le $MaxAttempts) {
        try {
            & $ScriptBlock
            return
        } catch {
            Write-LogWarn "Command failed (attempt $attempt/$MaxAttempts): $_"
            if ($attempt -eq $MaxAttempts) { throw }
            Start-Sleep -Seconds $DelaySeconds
            $attempt++
        }
    }
}

function Get-Checksum {
    param([string]$FilePath)
    $hash = Get-FileHash -Path $FilePath -Algorithm SHA256
    return $hash.Hash.ToLower()
}
