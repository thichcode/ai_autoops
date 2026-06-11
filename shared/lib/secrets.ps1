# secrets.ps1 — ISO 27001 A.9.4 credential management
# Reads from .env file (gitignored) or environment variables
# Usage: . .\secrets.ps1; $token = Get-Secret "SD_API_TOKEN"

$Script:EnvFile = Join-Path $PSScriptRoot "..\..\.env"

function Get-Secret {
    param([string]$Name)
    $val = [Environment]::GetEnvironmentVariable($Name)
    if ($val) { return $val }
    if (Test-Path $Script:EnvFile) {
        $line = Select-String -Path $Script:EnvFile -Pattern "^$Name=(.+)$"
        if ($line) {
            return $line.Matches.Groups[1].Value.Trim('"', "'")
        }
    }
    throw "Secret $Name not found in environment or .env file"
}

function Get-SecretSecure {
    param([string]$Name)
    $val = Get-Secret $Name
    return ConvertTo-SecureString $val -AsPlainText -Force
}
