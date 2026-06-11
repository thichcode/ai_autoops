# log.ps1 — Structured JSON logging for PowerShell
# Usage: . .\log.ps1; Write-LogInfo "message"

$Script:LogLevel = if ($env:LOG_LEVEL) { $env:LOG_LEVEL } else { "INFO" }
$Script:LogFile  = if ($env:LOG_FILE)  { $env:LOG_FILE  } else { "C:\ProgramData\AI_Ops\Logs\operations.log" }

$Script:LogLevels = @{ "DEBUG" = 0; "INFO" = 1; "WARN" = 2; "ERROR" = 3; "FATAL" = 4 }

function Write-Log {
    param([string]$Level, [string]$Message)
    $timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    $scriptName = (Get-PSCallStack)[1].ScriptName
    if (-not $scriptName) { $scriptName = "global" }
    $user = ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $hostname = [Environment]::MachineName

    if ($Script:LogLevels[$Level] -ge $Script:LogLevels[$Script:LogLevel]) {
        $logEntry = @{
            timestamp = $timestamp
            level     = $Level
            script    = $scriptName
            user      = $user
            host      = $hostname
            message   = $Message
        }
        $json = $logEntry | ConvertTo-Json -Compress
        $logDir = Split-Path $Script:LogFile -Parent
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force > $null }
        Add-Content -Path $Script:LogFile -Value $json
        if ($Level -in @("ERROR","FATAL")) {
            Write-Host $json -ForegroundColor Red
        } else {
            Write-Host $json
        }
    }
}

function Write-LogDebug { Write-Log "DEBUG" $args[0] }
function Write-LogInfo  { Write-Log "INFO"  $args[0] }
function Write-LogWarn  { Write-Log "WARN"  $args[0] }
function Write-LogError { Write-Log "ERROR" $args[0] }
function Write-LogFatal { Write-Log "FATAL" $args[0] }
