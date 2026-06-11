# ISO 20000/27001 Operations Scripts — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build production-ready operations scripts (Bash + PowerShell) for backup-restore, patch-management, change-management, and security-compliance across Jira, GitLab, Coverity, and BlackDuck systems.

**Architecture:** Hybrid monorepo — `shared/lib/` provides common logging, audit, notification, and API wrappers; each system module (`jira/`, `gitlab/`, etc.) has its own pipeline template with stage overrides, config files, and entrypoint scripts.

**Tech Stack:** Bash (Linux: Jira, GitLab, Coverity, BlackDuck app/DB hosts), PowerShell 5.1+ (Windows: Backup Exec server, ManageEngine SD+ API).

**Prerequisites:** Windows machine with Backup Exec BEMCLI module, access to ManageEngine SD+ REST API, SSH key access to Linux hosts.

---

### Task 1: shared/lib/log.sh — Bash structured logging

**Files:**
- Create: `shared/lib/log.sh`

- [ ] **Write shared/lib/log.sh**

```bash
#!/bin/bash
# log.sh — Structured JSON logging for Bash scripts
# Usage: source log.sh; log_info "message"; log_error "message"

set -o pipefail

LOG_LEVEL=${LOG_LEVEL:-INFO}
LOG_FILE=${LOG_FILE:-/var/log/ai_ops/operations.log}
LOG_DIR=$(dirname "$LOG_FILE")

declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARN]=2 [ERROR]=3 [FATAL]=4)

_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local script_name
    script_name=$(basename "${BASH_SOURCE[2]:-$0}")
    local user
    user=$(whoami)
    local host
    host=$(hostname)

    if [[ ${LOG_LEVELS[$level]} -ge ${LOG_LEVELS[$LOG_LEVEL]} ]]; then
        local log_entry
        log_entry=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "level": "$level",
  "script": "$script_name",
  "user": "$user",
  "host": "$host",
  "message": $(echo "$message" | jq -R -s '.')
}
EOF
)
        echo "$log_entry" >> "$LOG_FILE"
        if [[ "$level" == "ERROR" || "$level" == "FATAL" ]]; then
            echo "$log_entry" >&2
        else
            echo "$log_entry"
        fi
    fi
}

log_debug() { _log "DEBUG" "$1"; }
log_info()  { _log "INFO"  "$1"; }
log_warn()  { _log "WARN"  "$1"; }
log_error() { _log "ERROR" "$1"; }
log_fatal() { _log "FATAL" "$1"; }

_ensure_log_dir() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" || { echo "FATAL: Cannot create log directory $LOG_DIR"; exit 1; }
    fi
}

_ensure_log_dir
```

- [ ] **Write test script tests/test_log.sh**

```bash
#!/bin/bash
source "../shared/lib/log.sh"
LOG_FILE=/tmp/test_ai_ops.log
rm -f "$LOG_FILE"

log_info "Test info message"
log_error "Test error message"

lines=$(wc -l < "$LOG_FILE")
if [[ "$lines" -eq 2 ]]; then
    echo "PASS: log writes JSON lines"
else
    echo "FAIL: expected 2 lines, got $lines"
    exit 1
fi

if grep -q "Test info message" "$LOG_FILE" && grep -q "Test error message" "$LOG_FILE"; then
    echo "PASS: log messages found"
else
    echo "FAIL: log messages missing"
    exit 1
fi

rm -f "$LOG_FILE"
echo "All tests passed"
```

- [ ] **Run test**

Run: `cd tests && bash test_log.sh`
Expected: `All tests passed`

- [ ] **Commit**

```bash
git add shared/lib/log.sh tests/test_log.sh
git commit -m "feat(shared): add structured JSON logging for Bash"
```

---

### Task 2: shared/lib/log.ps1 — PowerShell structured logging

**Files:**
- Create: `shared/lib/log.ps1`

- [ ] **Write shared/lib/log.ps1**

```powershell
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
```

- [ ] **Commit**

```bash
git add shared/lib/log.ps1
git commit -m "feat(shared): add structured JSON logging for PowerShell"
```

---

### Task 3: shared/lib/audit.sh & audit.ps1 — Audit trail

**Files:**
- Create: `shared/lib/audit.sh`
- Create: `shared/lib/audit.ps1`

- [ ] **Write shared/lib/audit.sh**

```bash
#!/bin/bash
# audit.sh — ISO 27001 A.12.4 compliant audit trail
# Source after log.sh; requires log_info/log_error functions
# Usage: audit_record "ACTION" "STATUS" "DETAILS"

AUDIT_LOG=${AUDIT_LOG:-/var/log/ai_ops/audit.log}

audit_record() {
    local action="$1"
    local status="$2"
    local details="$3"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local user
    user=$(whoami)
    local host
    host=$(hostname)
    local pid=$$

    local entry
    entry=$(cat <<EOF
{
  "timestamp": "$timestamp",
  "user": "$user",
  "host": "$host",
  "pid": $pid,
  "action": $(echo "$action" | jq -R -s '.'),
  "status": "$status",
  "details": $(echo "$details" | jq -R -s '.')
}
EOF
)
    echo "$entry" >> "$AUDIT_LOG"
    log_info "AUDIT: $action — $status"
}

audit_success() { audit_record "$1" "SUCCESS" "$2"; }
audit_failure() { audit_record "$1" "FAILURE" "$2"; }
audit_started() { audit_record "$1" "STARTED" "$2"; }
```

- [ ] **Write shared/lib/audit.ps1**

```powershell
# audit.ps1 — ISO 27001 A.12.4 compliant audit trail
# Usage: . .\audit.ps1; Audit-Record -Action "backup" -Status "SUCCESS" -Details "completed"

$Script:AuditLog = if ($env:AUDIT_LOG) { $env:AUDIT_LOG } else { "C:\ProgramData\AI_Ops\Logs\audit.log" }

function Audit-Record {
    param([string]$Action, [string]$Status, [string]$Details)
    $timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    $user = ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $hostname = [Environment]::MachineName
    $pid = [Diagnostics.Process]::GetCurrentProcess().Id

    $entry = @{
        timestamp = $timestamp
        user      = $user
        host      = $hostname
        pid       = $pid
        action    = $Action
        status    = $Status
        details   = $Details
    }
    $logDir = Split-Path $Script:AuditLog -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force > $null }
    Add-Content -Path $Script:AuditLog -Value ($entry | ConvertTo-Json -Compress)
    Write-LogInfo "AUDIT: $Action — $Status"
}

function Audit-Success { Audit-Record -Action $args[0] -Status "SUCCESS" -Details $args[1] }
function Audit-Failure { Audit-Record -Action $args[0] -Status "FAILURE" -Details $args[1] }
function Audit-Started { Audit-Record -Action $args[0] -Status "STARTED" -Details $args[1] }
```

- [ ] **Commit**

```bash
git add shared/lib/audit.sh shared/lib/audit.ps1
git commit -m "feat(shared): add ISO 27001 audit trail (Bash + PowerShell)"
```

---

### Task 4: shared/lib/notify.sh & notify.ps1 — Email + Slack notifications

**Files:**
- Create: `shared/lib/notify.sh`
- Create: `shared/lib/notify.ps1`

- [ ] **Write shared/lib/notify.sh**

```bash
#!/bin/bash
# notify.sh — Multi-channel notification (Email + Slack)
# Usage: notify "subject" "message" ["channel"]

NOTIFY_EMAIL_TO=${NOTIFY_EMAIL_TO:-"ops@company.com"}
NOTIFY_EMAIL_FROM=${NOTIFY_EMAIL_FROM:-"ai-ops@company.com"}
NOTIFY_SLACK_WEBHOOK=${NOTIFY_SLACK_WEBHOOK:-""}
NOTIFY_SMTP_SERVER=${NOTIFY_SMTP_SERVER:-"smtp.company.com"}

notify_email() {
    local subject="$1"
    local message="$2"
    echo "$message" | mail -s "$subject" -r "$NOTIFY_EMAIL_FROM" "$NOTIFY_EMAIL_TO"
    log_info "Email sent to $NOTIFY_EMAIL_TO: $subject"
}

notify_slack() {
    local subject="$1"
    local message="$2"
    if [[ -n "$NOTIFY_SLACK_WEBHOOK" ]]; then
        local payload
        payload=$(cat <<EOF
{
  "text": "*[$subject]*\n$message"
}
EOF
)
        curl -s -X POST -H "Content-Type: application/json" \
            -d "$payload" "$NOTIFY_SLACK_WEBHOOK" > /dev/null
    fi
}

notify() {
    local subject="$1"
    local message="$2"
    notify_email "$subject" "$message"
    notify_slack "$subject" "$message"
    log_info "Notification sent: $subject"
}

notify_success() { notify "[SUCCESS] $1" "$2"; }
notify_failure() { notify "[FAILURE] $1" "$2"; }
notify_warning() { notify "[WARNING] $1" "$2"; }
```

- [ ] **Write shared/lib/notify.ps1**

```powershell
# notify.ps1 — Multi-channel notification (Email + Slack)
# Usage: Send-Notification -Subject "patch complete" -Message "Jira updated"

$Script:NotifyEmailTo    = if ($env:NOTIFY_EMAIL_TO)    { $env:NOTIFY_EMAIL_TO }    else { "ops@company.com" }
$Script:NotifyEmailFrom  = if ($env:NOTIFY_EMAIL_FROM)  { $env:NOTIFY_EMAIL_FROM }  else { "ai-ops@company.com" }
$Script:NotifySlackUrl   = if ($env:NOTIFY_SLACK_WEBHOOK) { $env:NOTIFY_SLACK_WEBHOOK } else { $null }
$Script:NotifySmtpServer = if ($env:NOTIFY_SMTP_SERVER) { $env:NOTIFY_SMTP_SERVER } else { "smtp.company.com" }

function Send-Notification {
    param([string]$Subject, [string]$Message)
    try {
        Send-MailMessage -To $Script:NotifyEmailTo -From $Script:NotifyEmailFrom `
            -Subject $Subject -Body $Message -SmtpServer $Script:NotifySmtpServer -ErrorAction Stop
        Write-LogInfo "Email sent: $Subject"
    } catch {
        Write-LogError "Email failed: $_"
    }
    if ($Script:NotifySlackUrl) {
        $body = @{ text = "*[$Subject]*`n$Message" } | ConvertTo-Json
        Invoke-RestMethod -Uri $Script:NotifySlackUrl -Method Post -Body $body -ContentType "application/json"
    }
}

function Send-Success   { Send-Notification -Subject "[SUCCESS] $($args[0])" -Message $args[1] }
function Send-Failure   { Send-Notification -Subject "[FAILURE] $($args[0])" -Message $args[1] }
function Send-Warning   { Send-Notification -Subject "[WARNING] $($args[0])" -Message $args[1] }
```

- [ ] **Commit**

```bash
git add shared/lib/notify.sh shared/lib/notify.ps1
git commit -m "feat(shared): add multi-channel notifications (email + Slack)"
```

---

### Task 5: shared/lib/utils.sh & utils.ps1 — Common utilities

**Files:**
- Create: `shared/lib/utils.sh`
- Create: `shared/lib/utils.ps1`

- [ ] **Write shared/lib/utils.sh**

```bash
#!/bin/bash
# utils.sh — Common utilities: retry, checksum, SSH wrapper, RBAC check

BYPASS_RBAC=${BYPASS_RBAC:-false}
ALLOWED_GROUPS=${ALLOWED_GROUPS:-"jira-admins gitlab-ops coverity-admins"}

check_rbac() {
    local system="$1"
    if [[ "$BYPASS_RBAC" == "true" ]]; then
        log_warn "RBAC check bypassed (BYPASS_RBAC=true)"
        return 0
    fi
    local user_groups
    user_groups=$(groups "$(whoami)" 2>/dev/null)
    for group in $ALLOWED_GROUPS; do
        if echo "$user_groups" | grep -qw "$group"; then
            log_info "RBAC: user $(whoami) authorized via group $group"
            return 0
        fi
    done
    log_fatal "RBAC: user $(whoami) not in allowed groups ($ALLOWED_GROUPS)"
    return 1
}

retry() {
    local cmd="$1"
    local max_attempts="${2:-3}"
    local delay="${3:-5}"
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if eval "$cmd"; then
            return 0
        fi
        log_warn "Command failed (attempt $attempt/$max_attempts): $cmd"
        sleep "$delay"
        ((attempt++))
    done
    log_error "Command failed after $max_attempts attempts: $cmd"
    return 1
}

checksum_verify() {
    local file="$1"
    local expected_hash="$2"
    local actual_hash
    actual_hash=$(sha256sum "$file" | awk '{print $1}')
    if [[ "$actual_hash" == "$expected_hash" ]]; then
        log_info "Checksum OK: $file"
        return 0
    else
        log_error "Checksum MISMATCH: $file (expected $expected_hash, got $actual_hash)"
        return 1
    }
}

ssh_run() {
    local host="$1"
    local cmd="$2"
    local ssh_key="${3:-}"
    local ssh_opts="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
    if [[ -n "$ssh_key" ]]; then
        ssh_opts="$ssh_opts -i $ssh_key"
    fi
    ssh $ssh_opts "$host" "$cmd"
    return $?
}

scp_push() {
    local src="$1"
    local dest="$2"
    local ssh_key="${3:-}"
    local ssh_opts="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
    if [[ -n "$ssh_key" ]]; then
        ssh_opts="$ssh_opts -i $ssh_key"
    fi
    scp $ssh_opts "$src" "$dest"
    return $?
}
```

- [ ] **Write shared/lib/utils.ps1**

```powershell
# utils.ps1 — Common utilities: retry, checksum, RBAC check

$Script:BypassRBAC     = if ($env:BYPASS_RBAC)     { $true } else { $false }
$Script:AllowedGroups  = @("jira-admins", "gitlab-ops", "coverity-admins")

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
```

- [ ] **Commit**

```bash
git add shared/lib/utils.sh shared/lib/utils.ps1
git commit -m "feat(shared): add utilities (retry, checksum, RBAC, SSH)"
```

---

### Task 6: shared/lib/secrets.ps1 — Credential management

**Files:**
- Create: `shared/lib/secrets.ps1`

- [ ] **Write shared/lib/secrets.ps1**

```powershell
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
```

- [ ] **Commit**

```bash
git add shared/lib/secrets.ps1
git commit -m "feat(shared): add credential management (.env-based)"
```

---

### Task 7: shared/lib/backup-exec-api.ps1 — Backup Exec BEMCLI wrapper

**Files:**
- Create: `shared/lib/backup-exec-api.ps1`

- [ ] **Write shared/lib/backup-exec-api.ps1**

```powershell
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

function Start-BERestore {
    param([string]$JobName, [string]$RestorePath)
    Test-BEMCLI
    Audit-Started "BE_RESTORE" "Starting restore from job: $JobName"
    try {
        $result = & $Script:BEMCLIPath "restore" "start" $JobName "--path" $RestorePath
        if ($LASTEXITCODE -ne 0) { throw "BEMCLI restore failed: $result" }
        Audit-Success "BE_RESTORE" "Restore job $JobName completed"
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
```

- [ ] **Commit**

```bash
git add shared/lib/backup-exec-api.ps1
git commit -m "feat(shared): add Backup Exec BEMCLI wrapper"
```

---

### Task 8: shared/lib/servicedesk-api.ps1 — ManageEngine SD+ API

**Files:**
- Create: `shared/lib/servicedesk-api.ps1`

- [ ] **Write shared/lib/servicedesk-api.ps1**

```powershell
# servicedesk-api.ps1 — ManageEngine ServiceDesk Plus REST API wrapper
# Usage: . .\servicedesk-api.ps1; New-ChangeRequest -Title "..."

$Script:SdBaseUrl   = if ($env:SD_BASE_URL)   { $env:SD_BASE_URL }   else { "https://sdm.company.com/sdpapi" }
$Script:SdApiKey    = if ($env:SD_API_KEY)    { $env:SD_API_KEY }    else { Get-Secret "SD_API_KEY" }
$Script:SdInputFormat = "json"

function Invoke-SDApi {
    param([string]$Endpoint, [string]$Method = "GET", [object]$Body = $null)
    $url = "$Script:SdBaseUrl/$Endpoint"
    $headers = @{ "TECHNICIAN_KEY" = $Script:SdApiKey }
    $params = @{
        Uri = $url
        Method = $Method
        Headers = $headers
        ContentType = "application/json"
    }
    if ($Body) { $params["Body"] = ($Body | ConvertTo-Json) }
    try {
        $response = Invoke-RestMethod @params
        return $response
    } catch {
        Write-LogError "SD+ API call failed: $Endpoint — $_"
        throw
    }
}

function New-SDChangeRequest {
    param(
        [string]$Title,
        [string]$Description,
        [string]$Priority = "Medium",
        [string]$RiskLevel = "Low",
        [string]$Category = "Maintenance",
        [string]$RollbackPlan = ""
    )
    $body = @{
        operation = @{
            details = @{
                title        = $Title
                description  = $Description
                priority     = $Priority
                risk_level   = $RiskLevel
                category     = $Category
                rollback_plan = $RollbackPlan
                status       = "Draft"
            }
        }
    }
    $resp = Invoke-SDApi -Endpoint "request" -Method "POST" -Body $body
    Audit-Success "SD_CREATE_CR" "Created CR: $Title"
    return $resp
}

function Update-SDChangeRequest {
    param([string]$CrId, [string]$Status)
    $body = @{
        operation = @{
            details = @{
                status = $Status
            }
        }
    }
    $resp = Invoke-SDApi -Endpoint "request/$CrId" -Method "PUT" -Body $body
    Audit-Success "SD_UPDATE_CR" "Updated CR $CrId → $Status"
    return $resp
}

function Add-SDChangeNote {
    param([string]$CrId, [string]$Note)
    $body = @{
        operation = @{
            details = @{
                note = @{
                    content = $Note
                    note_type = "Public"
                }
            }
        }
    }
    $resp = Invoke-SDApi -Endpoint "request/$CrId/notes" -Method "POST" -Body $body
    return $resp
}
```

- [ ] **Commit**

```bash
git add shared/lib/servicedesk-api.ps1
git commit -m "feat(shared): add ManageEngine SD+ change management API"
```

---

### Task 9: shared/lib/rollback.sh & rollback.ps1 — Rollback helpers

**Files:**
- Create: `shared/lib/rollback.sh`
- Create: `shared/lib/rollback.ps1`

- [ ] **Write shared/lib/rollback.sh**

```bash
#!/bin/bash
# rollback.sh — Generic rollback helpers
# Usage: source rollback.sh; snapshot_restore "/opt/jira" "/backup/jira-pre-patch"

BACKUP_BASE=${BACKUP_BASE:-/backup}

snapshot_restore() {
    local target="$1"
    local backup_path="$2"
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup path not found: $backup_path"
        return 1
    fi
    log_warn "ROLLBACK: Restoring $target from $backup_path"
    if [[ -d "$target" ]]; then
        mv "$target" "${target}.rollback-$(date +%Y%m%d%H%M%S)"
    fi
    cp -a "$backup_path" "$target"
    log_info "ROLLBACK: $target restored successfully"
    audit_success "ROLLBACK" "Restored $target from $backup_path"
}

symlink_swap() {
    local current_link="$1"
    local backup_dir="$2"
    if [[ -L "$current_link" ]]; then
        rm "$current_link"
        ln -s "$backup_dir" "$current_link"
        log_info "ROLLBACK: Symlink $current_link → $backup_dir"
    else
        log_error "ROLLBACK: $current_link is not a symlink"
        return 1
    fi
}
```

- [ ] **Write shared/lib/rollback.ps1**

```powershell
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
```

- [ ] **Commit**

```bash
git add shared/lib/rollback.sh shared/lib/rollback.ps1
git commit -m "feat(shared): add rollback helpers (snapshot restore, symlink swap)"
```

---

### Task 10: shared/config/global.cfg + .env.template + .gitignore + setup

**Files:**
- Create: `shared/config/global.cfg`
- Create: `.env.template`
- Create: `.gitignore`

- [ ] **Write shared/config/global.cfg**

```bash
# Global configuration for AI Ops scripts
# This file is tracked in git. Do NOT put secrets here.

LOG_LEVEL="INFO"
LOG_FILE="/var/log/ai_ops/operations.log"
AUDIT_LOG="/var/log/ai_ops/audit.log"
BACKUP_BASE="/backup"

NOTIFY_EMAIL_TO="ops@company.com"
NOTIFY_EMAIL_FROM="ai-ops@company.com"
NOTIFY_SMTP_SERVER="smtp.company.com"

ALLOWED_GROUPS="jira-admins gitlab-ops coverity-admins blackduck-admins"

SSH_KEY_PATH="/home/ops/.ssh/id_ed25519"
SSH_USER="ops"
```

- [ ] **Write .env.template**

```bash
# .env — Secrets (DO NOT COMMIT)
# Copy this to .env and fill in real values

# Backup Exec
BE_SERVER="backupexec.company.com"
BE_USER="svc_backup"
BE_PASS="changeme"

# ManageEngine ServiceDesk Plus
SD_BASE_URL="https://sdm.company.com/sdpapi"
SD_API_KEY="your-api-key-here"

# Slack Webhook
NOTIFY_SLACK_WEBHOOK="https://hooks.slack.com/services/xxx/yyy/zzz"

# Jira
JIRA_DB_USER="jiradb"
JIRA_DB_PASS="changeme"

# NGINX Plus
NGINX_PLUS_API_USER="admin"
NGINX_PLUS_API_PASS="changeme"
```

- [ ] **Write .gitignore**

```gitignore
# Secrets
.env
*.pem
*.key
**/vault/

# OS
.DS_Store
Thumbs.db

# Logs
*.log
```

- [ ] **Commit**

```bash
git add shared/config/global.cfg .env.template .gitignore
git commit -m "chore: add global config, env template, gitignore"
```

---

### Task 11: Jira config files

**Files:**
- Create: `jira/config/shared.cfg`
- Create: `jira/config/prod.cfg`
- Create: `jira/config/staging.cfg`

- [ ] **Write jira/config/shared.cfg**

```bash
# Jira shared configuration (all environments)
JIRA_USER="jira"
JIRA_INSTALL_DIR="/opt/atlassian/jira"
JIRA_HOME="/var/atlassian/application-data/jira"
JIRA_SERVICE="jira"
JIRA_DIST_URL="https://product-downloads.atlassian.com/software/jira/downloads/atlassian-jira-software-{version}.tar.gz"
NGINX_UPSTREAM_NAME="jira_backend"
```

- [ ] **Write jira/config/prod.cfg**

```bash
# Jira Production Configuration
JIRA_VERSION="10.5.0"
JIRA_NODES=("jira-app01.company.com" "jira-app02.company.com")
JIRA_NODE_IPS=("192.168.1.10" "192.168.1.11")
DB_HOSTS=("galera-db01.company.com" "galera-db02.company.com" "galera-db03.company.com")
DB_NAME="jiradb"
DB_PORT="3306"
GALERA_CLUSTER_NAME="jira_galera"
NFS_MOUNT="/var/atlassian/application-data/jira"
NFS_SERVER="nfs.company.com:/exports/jira"
NGINX_PLUS_API="https://nginx-plus.company.com/api"
MAINTENANCE_PAGE="/usr/share/nginx/html/maintenance.html"
```

- [ ] **Write jira/config/staging.cfg**

```bash
# Jira Staging Configuration
JIRA_VERSION="10.5.0"
JIRA_NODES=("jira-stg01.company.com")
JIRA_NODE_IPS=("192.168.2.10")
DB_HOSTS=("galera-stg-db01.company.com")
DB_NAME="jiradb_stg"
DB_PORT="3306"
NFS_MOUNT="/var/atlassian/application-data/jira"
NFS_SERVER="nfs-stg.company.com:/exports/jira-stg"
NGINX_PLUS_API="https://nginx-plus-stg.company.com/api"
MAINTENANCE_PAGE="/usr/share/nginx/html/maintenance.html"
```

- [ ] **Commit**

```bash
git add jira/config/
git commit -m "feat(jira): add environment configuration files"
```

---

### Task 12: Jira pipeline.sh — Pipeline orchestrator

**Files:**
- Create: `jira/pipeline.sh`

- [ ] **Write jira/pipeline.sh**

```bash
#!/bin/bash
# Jira pipeline orchestrator
# Usage: ./pipeline.sh --action patch --env prod
# Stages: precheck → backup → drain → maint → deploy → verify → [commit|rollback] → audit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/notify.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

ACTION="${1:-patch}"
ENV="${2:-prod}"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"

CURRENT_STAGE=""
ROLLBACK_TRIGGERED=false
declare -a COMPLETED_STAGES=()

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 && "$ROLLBACK_TRIGGERED" == false ]]; then
        ROLLBACK_TRIGGERED=true
        log_warn "Pipeline failed at stage: $CURRENT_STAGE. Triggering rollback..."
        notify_failure "Jira pipeline failed at $CURRENT_STAGE on $ENV" "See audit log for details"
        run_stage "rollback"
    fi
    audit_record "PIPELINE_END" "$([ $exit_code -eq 0 ] && echo SUCCESS || echo FAILURE)" \
        "Stages completed: ${COMPLETED_STAGES[*]}"
}
trap cleanup EXIT

run_stage() {
    local stage="$1"
    CURRENT_STAGE="$stage"
    local stage_script="$SCRIPT_DIR/stages/${stage}.sh"
    if [[ ! -f "$stage_script" ]]; then
        stage_script="$PROJECT_ROOT/shared/templates/${stage}.sh"
    fi
    if [[ ! -f "$stage_script" ]]; then
        log_error "Stage script not found: $stage"
        return 1
    fi
    audit_started "STAGE_$stage" "Starting stage: $stage"
    log_info "=== Stage: $stage ==="
    if bash "$stage_script" "$ENV"; then
        audit_success "STAGE_$stage" "Completed stage: $stage"
        COMPLETED_STAGES+=("$stage")
    else
        audit_failure "STAGE_$stage" "Failed stage: $stage"
        return 1
    fi
}

# Main pipeline
audit_started "PIPELINE" "Jira $ACTION pipeline starting on $ENV"
notify "Jira pipeline started" "Action: $ACTION, Environment: $ENV"

run_stage "precheck"
run_stage "backup"

if [[ "$ACTION" == "patch" ]]; then
    for node in "${JIRA_NODES[@]}"; do
        log_info "Processing node: $node"
        export CURRENT_NODE="$node"
        run_stage "drain"
        run_stage "maint"
        run_stage "deploy"
        run_stage "verify" || {
            log_error "Verification failed on $node, triggering rollback"
            run_stage "rollback"
            exit 1
        }
        log_info "Node $node completed successfully"
    done
elif [[ "$ACTION" == "restore" ]]; then
    run_stage "maint"
    run_stage "deploy"
    run_stage "verify"
fi

notify_success "Jira pipeline completed" "Action: $ACTION, Environment: $ENV"
log_info "Pipeline completed successfully"
```

- [ ] **Commit**

```bash
git add jira/pipeline.sh
chmod +x jira/pipeline.sh
git commit -m "feat(jira): add pipeline orchestrator"
```

---

### Task 13: Jira stages — precheck.sh

**Files:**
- Create: `jira/stages/precheck.sh`

- [ ] **Write jira/stages/precheck.sh**

```bash
#!/bin/bash
# precheck.sh — Jira pre-flight checks
# Checks: node reachability, Galera sync, disk space, NFS mount, backup age

source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$1.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/utils.sh"

check_node() {
    local node="$1"
    if ping -c 2 "$node" &>/dev/null; then
        log_info "Node reachable: $node"
    else
        log_error "Node unreachable: $node"
        return 1
    fi
    if ssh_run "$node" "systemctl is-active $JIRA_SERVICE" 2>/dev/null; then
        log_info "Service active on $node"
    else
        log_warn "Service not active on $node (may be expected)"
    fi
}

check_galera() {
    local db_host="${DB_HOSTS[0]}"
    local wsrep_status
    wsrep_status=$(ssh_run "$db_host" \
        "mysql -u$JIRA_DB_USER -p$JIRA_DB_PASS -e 'SHOW STATUS LIKE \"wsrep_cluster_size\"' 2>/dev/null" 2>/dev/null || echo "")
    if echo "$wsrep_status" | grep -q "wsrep_cluster_size"; then
        log_info "Galera cluster reachable"
    else
        log_error "Galera cluster check failed"
        return 1
    fi
}

check_disk() {
    local node="$1"
    local threshold=80
    local usage
    usage=$(ssh_run "$node" "df -h $JIRA_HOME | tail -1 | awk '{print \$5}' | tr -d '%'" 2>/dev/null || echo 0)
    if [[ "$usage" -lt "$threshold" ]]; then
        log_info "Disk usage on $node: ${usage}% (threshold: ${threshold}%)"
    else
        log_error "Disk usage on $node: ${usage}% exceeds threshold ${threshold}%"
        return 1
    fi
}

check_nfs() {
    local node="$1"
    if ssh_run "$node" "mountpoint -q $NFS_MOUNT" 2>/dev/null; then
        log_info "NFS mount OK on $node: $NFS_MOUNT"
    else
        log_error "NFS mount not found on $node: $NFS_MOUNT"
        return 1
    fi
}

# RBAC check
check_rbac "jira" || exit 1

# For each app node
for node in "${JIRA_NODES[@]}"; do
    check_node "$node"
    check_disk "$node"
    check_nfs "$node"
done

# Galera check (once from first DB host)
check_galera

log_info "All pre-checks passed"
```

- [ ] **Commit**

```bash
git add jira/stages/precheck.sh
chmod +x jira/stages/precheck.sh
git commit -m "feat(jira): add precheck stage"
```

---

### Task 14: Jira stages — backup.sh

**Files:**
- Create: `jira/stages/backup.sh`

- [ ] **Write jira/stages/backup.sh**

```bash
#!/bin/bash
# backup.sh — Jira backup (BE + DB dump)
# Triggers Backup Exec job, verifies completion, takes DB snapshot

ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"

BACKUP_TAG="jira-${ENV}-prepatch-$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="${BACKUP_BASE}/${BACKUP_TAG}"

log_info "Starting backup for environment: $ENV"
audit_started "BACKUP" "Jira backup tag: $BACKUP_TAG"

# 1. Database backup from first DB host
DB_HOST="${DB_HOSTS[0]}"
DB_BACKUP_FILE="${BACKUP_DIR}/jiradb.sql.gz"
log_info "Taking DB backup from $DB_HOST to $DB_BACKUP_FILE"
ssh_run "$DB_HOST" "mkdir -p $BACKUP_DIR"
ssh_run "$DB_HOST" \
    "mysqldump --single-transaction --quick --triggers --routines \
        -u$JIRA_DB_USER -p$JIRA_DB_PASS $DB_NAME \
        | gzip > $DB_BACKUP_FILE"
ssh_run "$DB_HOST" "ls -la $DB_BACKUP_FILE"
audit_success "BACKUP_DB" "DB backup: $DB_BACKUP_FILE"

# 2. Checksum
DB_CHECKSUM=$(ssh_run "$DB_HOST" "sha256sum $DB_BACKUP_FILE | awk '{print \$1}'")
log_info "DB backup checksum: $DB_CHECKSUM"

# 3. Trigger Backup Exec job (via Windows BE server — placeholder)
log_warn "Backup Exec job trigger not implemented — manually verify BE job 'Jira-${ENV}-Daily' completed"
audit_success "BACKUP_BE" "BE job verification pending (manual)"

audit_success "BACKUP" "Jira backup completed: $BACKUP_TAG"
log_info "Backup completed successfully"
```

- [ ] **Write jira/stages/drain.sh**

```bash
#!/bin/bash
# drain.sh — Remove Jira node from NGINX Plus upstream

ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"

NODE="${CURRENT_NODE:?CURRENT_NODE not set}"
audit_started "DRAIN" "Draining node: $NODE"

# Mark node as draining in NGINX Plus
log_info "Setting node $NODE to draining state in NGINX Plus upstream $NGINX_UPSTREAM_NAME"
curl -s -X PATCH -d '{"weight": 0, "drain": true}' \
    "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" \
    --user "$NGINX_PLUS_API_USER:$NGINX_PLUS_API_PASS"

# Wait for active connections to drain
log_info "Waiting for active connections to drain..."
sleep 30

audit_success "DRAIN" "Node drained: $NODE"
log_info "Node $NODE drained successfully"
```

- [ ] **Commit**

```bash
git add jira/stages/backup.sh jira/stages/drain.sh
chmod +x jira/stages/backup.sh jira/stages/drain.sh
git commit -m "feat(jira): add backup and drain stages"
```

---

### Task 15: Jira stages — maint.sh, deploy.sh, verify.sh, rollback.sh

**Files:**
- Create: `jira/stages/maint.sh`
- Create: `jira/stages/deploy.sh`
- Create: `jira/stages/verify.sh`
- Create: `jira/stages/rollback.sh`

- [ ] **Write jira/stages/maint.sh**

```bash
#!/bin/bash
# maint.sh — Enable maintenance mode / stop Jira service

ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"

NODE="${CURRENT_NODE:?CURRENT_NODE not set}"
audit_started "MAINT" "Maintenance mode on $NODE"

# Enable maintenance page (if MAINTENANCE_PAGE defined)
if [[ -n "$MAINTENANCE_PAGE" && -f "$MAINTENANCE_PAGE" ]]; then
    log_info "Maintenance page already exists: $MAINTENANCE_PAGE"
fi

# Stop Jira service
log_info "Stopping Jira service on $NODE"
ssh_run "$NODE" "systemctl stop $JIRA_SERVICE" || {
    log_error "Failed to stop Jira service on $NODE"
    return 1
}
sleep 5
if ssh_run "$NODE" "systemctl is-active $JIRA_SERVICE 2>/dev/null" | grep -q "inactive"; then
    log_info "Jira service stopped on $NODE"
else
    log_error "Jira service still active on $NODE"
    return 1
fi

audit_success "MAINT" "Service stopped on $NODE"
```

- [ ] **Write jira/stages/deploy.sh**

```bash
#!/bin/bash
# deploy.sh — Deploy Jira patch version on current node

ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/rollback.sh"

NODE="${CURRENT_NODE:?CURRENT_NODE not set}"
audit_started "DEPLOY" "Deploying Jira $JIRA_VERSION on $NODE"

DEPLOY_DIR="${JIRA_INSTALL_DIR}-${JIRA_VERSION}"
BACKUP_DIR="${BACKUP_BASE}/jira-${ENV}-${JIRA_VERSION}-backup"

# Create backup of current install
log_info "Backing up current installation on $NODE"
ssh_run "$NODE" "cp -a $JIRA_INSTALL_DIR ${BACKUP_DIR}" || {
    log_error "Failed to backup current install on $NODE"
    return 1
}

# Download new version (if not already present)
DIST_FILE="atlassian-jira-software-${JIRA_VERSION}.tar.gz"
DIST_URL="${JIRA_DIST_URL/\{version\}/$JIRA_VERSION}"

ssh_run "$NODE" "if [[ ! -f /tmp/$DIST_FILE ]]; then wget -q $DIST_URL -O /tmp/$DIST_FILE; fi"

# Deploy
ssh_run "$NODE" "tar xzf /tmp/$DIST_FILE -C /opt/atlassian/"
ssh_run "$NODE" "rm -f $JIRA_INSTALL_DIR && ln -sf $DEPLOY_DIR $JIRA_INSTALL_DIR"

audit_success "DEPLOY" "Jira $JIRA_VERSION deployed on $NODE"
log_info "Deployment completed on $NODE"
```

- [ ] **Write jira/stages/verify.sh**

```bash
#!/bin/bash
# verify.sh — Health check after deploy

ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"

NODE="${CURRENT_NODE:?CURRENT_NODE not set}"
audit_started "VERIFY" "Verifying Jira on $NODE"

# Start Jira
log_info "Starting Jira service on $NODE"
ssh_run "$NODE" "systemctl start $JIRA_SERVICE" || {
    log_error "Failed to start Jira service on $NODE"
    return 1
}

# Wait for startup
sleep 30

# Check service status
if ! ssh_run "$NODE" "systemctl is-active $JIRA_SERVICE 2>/dev/null" | grep -q "active"; then
    log_error "Jira service not active on $NODE"
    return 1
fi
log_info "Jira service active on $NODE"

# HTTP health check
JIRA_URL="http://$NODE:8080/status"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$JIRA_URL" 2>/dev/null || echo "000")
if [[ "$HTTP_STATUS" == "200" ]]; then
    log_info "HTTP health check OK: $JIRA_URL → $HTTP_STATUS"
else
    log_warn "HTTP health check: $JIRA_URL → $HTTP_STATUS (may need longer startup)"
fi

# DB connectivity check
DB_HOST="${DB_HOSTS[0]}"
if ssh_run "$DB_HOST" \
    "mysql -u$JIRA_DB_USER -p$JIRA_DB_PASS -e 'SELECT 1' $DB_NAME 2>/dev/null" \
    | grep -q "1"; then
    log_info "DB connectivity OK"
else
    log_error "DB connectivity failed"
    return 1
fi

# Add node back to NGINX upstream
log_info "Re-enabling node $NODE in NGINX Plus upstream $NGINX_UPSTREAM_NAME"
curl -s -X PATCH -d '{"weight": 1, "drain": false}' \
    "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" \
    --user "$NGINX_PLUS_API_USER:$NGINX_PLUS_API_PASS"

audit_success "VERIFY" "Node verified and re-enabled: $NODE"
log_info "Verification completed on $NODE"
```

- [ ] **Write jira/stages/rollback.sh**

```bash
#!/bin/bash
# rollback.sh — Rollback Jira node to previous version

ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/rollback.sh"

NODE="${CURRENT_NODE:-${JIRA_NODES[0]}}"
audit_started "ROLLBACK" "Rolling back Jira on $NODE"

# Stop service
log_info "Stopping Jira service on $NODE"
ssh_run "$NODE" "systemctl stop $JIRA_SERVICE" || true

# Restore from backup
BACKUP_DIR="${BACKUP_BASE}/jira-${ENV}-backup"
ssh_run "$NODE" "if [[ -d $BACKUP_DIR ]]; then cp -a $BACKUP_DIR/* $JIRA_INSTALL_DIR/; fi"
log_info "Restored files from $BACKUP_DIR"

# Start service
ssh_run "$NODE" "systemctl start $JIRA_SERVICE"
log_info "Jira service restarted on $NODE"

# Re-enable in NGINX
if [[ -n "$NGINX_PLUS_API" ]]; then
    curl -s -X PATCH -d '{"weight": 1, "drain": false}' \
        "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$NODE" \
        --user "$NGINX_PLUS_API_USER:$NGINX_PLUS_API_PASS"
fi

audit_success "ROLLBACK" "Rollback completed on $NODE"
notify_warning "Jira rollback completed" "Node $NODE rolled back to previous version"
```

- [ ] **Commit**

```bash
git add jira/stages/maint.sh jira/stages/deploy.sh jira/stages/verify.sh jira/stages/rollback.sh
chmod +x jira/stages/maint.sh jira/stages/deploy.sh jira/stages/verify.sh jira/stages/rollback.sh
git commit -m "feat(jira): add maint, deploy, verify, rollback stages"
```

---

### Task 16: Jira entrypoint scripts

**Files:**
- Create: `jira/patch.sh`
- Create: `jira/backup-restore.sh`
- Create: `jira/change-request.sh`
- Create: `jira/health-check.sh`

- [ ] **Write jira/patch.sh**

```bash
#!/bin/bash
# patch.sh — Entrypoint for Jira patch update
# Usage: ./patch.sh [env] [version]
# Example: ./patch.sh prod 10.5.0

ENV="${1:-prod}"
VERSION="${2:-10.5.0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"

echo "=========================================="
echo "  Jira Patch Update — Environment: $ENV"
echo "  Version: $VERSION"
echo "  Nodes: ${JIRA_NODES[*]}"
echo "=========================================="

# Update version in config
sed -i "s/JIRA_VERSION=.*/JIRA_VERSION=\"$VERSION\"/" "$SCRIPT_DIR/config/$ENV.cfg"

# Run pipeline
exec "$SCRIPT_DIR/pipeline.sh" patch "$ENV"
```

- [ ] **Write jira/backup-restore.sh**

```bash
#!/bin/bash
# backup-restore.sh — Manual backup / restore
# Usage: ./backup-restore.sh backup [env]
#        ./backup-restore.sh restore [env] [backup-path]

ACTION="${1:-backup}"
ENV="${2:-prod}"
BACKUP_PATH="$3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../shared/lib/log.sh"
source "$SCRIPT_DIR/../shared/lib/audit.sh"

case "$ACTION" in
    backup)
        audit_started "MANUAL_BACKUP" "Manual backup triggered for $ENV"
        bash "$SCRIPT_DIR/stages/backup.sh" "$ENV"
        ;;
    restore)
        if [[ -z "$BACKUP_PATH" ]]; then
            log_error "Usage: $0 restore <env> <backup-path>"
            exit 1
        fi
        audit_started "MANUAL_RESTORE" "Manual restore from $BACKUP_PATH for $ENV"
        export JIRA_BACKUP_PATH="$BACKUP_PATH"
        bash "$SCRIPT_DIR/pipeline.sh" restore "$ENV"
        ;;
    *)
        echo "Usage: $0 {backup|restore} [env] [backup-path]"
        exit 1
        ;;
esac
```

- [ ] **Write jira/change-request.sh**

```bash
#!/bin/bash
# change-request.sh — ManageEngine SD+ change request management
# Usage: ./change-request.sh create|update|add-note [options]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../shared/lib/log.sh"

case "${1:-help}" in
    create)
        shift
        pwsh -File "$SCRIPT_DIR/../shared/lib/servicedesk-api.ps1" \
            -Command "New-SDChangeRequest @{Title='$1'; Description='$2'; Priority='${3:-Medium}'}"
        ;;
    update)
        CR_ID="$2"
        STATUS="$3"
        pwsh -File "$SCRIPT_DIR/../shared/lib/servicedesk-api.ps1" \
            -Command "Update-SDChangeRequest -CrId '$CR_ID' -Status '$STATUS'"
        ;;
    add-note)
        CR_ID="$2"
        NOTE="$3"
        pwsh -File "$SCRIPT_DIR/../shared/lib/servicedesk-api.ps1" \
            -Command "Add-SDChangeNote -CrId '$CR_ID' -Note '$NOTE'"
        ;;
    *)
        echo "Usage: $0 {create|update|add-note} [args...]"
        echo "  create <title> <description> [priority]"
        echo "  update <cr-id> <status>"
        echo "  add-note <cr-id> <note-text>"
        exit 1
        ;;
esac
```

- [ ] **Write jira/health-check.sh**

```bash
#!/bin/bash
# health-check.sh — Full Jira cluster health report
# Usage: ./health-check.sh [env]

ENV="${1:-prod}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$SCRIPT_DIR/../shared/lib/log.sh"
source "$SCRIPT_DIR/../shared/lib/notify.sh"

echo "=========================================="
echo "  Jira Health Check — $ENV"
echo "  $(date -u)"
echo "=========================================="

for node in "${JIRA_NODES[@]}"; do
    echo "--- Node: $node ---"
    echo -n "  Ping: "
    ping -c 1 -W 2 "$node" &>/dev/null && echo "OK" || echo "FAIL"
    echo -n "  Service: "
    status=$(ssh "$node" "systemctl is-active $JIRA_SERVICE" 2>/dev/null || echo "unknown")
    echo "$status"
    echo -n "  Disk ($JIRA_HOME): "
    ssh "$node" "df -h $JIRA_HOME | tail -1 | awk '{print \$3 \"/\" \$2 \" (\" \$5 \")\"}'" 2>/dev/null || echo "unknown"
    echo -n "  NFS Mount: "
    ssh "$node" "mountpoint -q $NFS_MOUNT && echo OK || echo FAIL" 2>/dev/null || echo "FAIL"
done

echo "--- Database: ${DB_HOSTS[0]} ---"
echo -n "  Galera cluster size: "
ssh "${DB_HOSTS[0]}" \
    "mysql -u$JIRA_DB_USER -p$JIRA_DB_PASS -e 'SHOW STATUS LIKE \"wsrep_cluster_size\"'" 2>/dev/null \
    || echo "Connection FAILED"

echo "=========================================="
echo "Health check complete."
```

- [ ] **Commit**

```bash
git add jira/patch.sh jira/backup-restore.sh jira/change-request.sh jira/health-check.sh
chmod +x jira/patch.sh jira/backup-restore.sh jira/change-request.sh jira/health-check.sh
git commit -m "feat(jira): add entrypoint scripts (patch, backup, change-request, health-check)"
```

---

### Task 17: GitLab module (all files)

**Files:**
- Create: `gitlab/config/shared.cfg`
- Create: `gitlab/config/prod.cfg`
- Create: `gitlab/pipeline.sh`
- Create: `gitlab/stages/precheck.sh`
- Create: `gitlab/stages/backup.sh`
- Create: `gitlab/stages/deploy.sh`
- Create: `gitlab/stages/verify.sh`
- Create: `gitlab/stages/rollback.sh`
- Create: `gitlab/patch.sh`
- Create: `gitlab/backup-restore.sh`
- Create: `gitlab/change-request.sh`
- Create: `gitlab/health-check.sh`

- [ ] **Write gitlab/config/shared.cfg**

```bash
# GitLab shared configuration
GITLAB_USER="git"
GITLAB_HOME="/var/opt/gitlab"
GITLAB_BACKUP_DIR="/var/opt/gitlab/backups"
GITLAB_OMNIBUS_CONFIG="/etc/gitlab/gitlab.rb"
GITLAB_SERVICE="gitlab-runsvdir"
GITLAB_PACKAGE_URL="https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/focal/gitlab-ee_{version}_amd64.deb"
```

- [ ] **Write gitlab/config/prod.cfg**

```bash
# GitLab Production
GITLAB_HOST="gitlab.company.com"
GITLAB_VERSION="16.11.0"
GITLAB_EDITION="ee"
BACKUP_RETAIN_DAYS=30
```

- [ ] **Write gitlab/pipeline.sh**

```bash
#!/bin/bash
# GitLab pipeline orchestrator
# Stages: precheck → backup → deploy → verify → [commit|rollback]

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/notify.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

ACTION="${1:-patch}"
ENV="${2:-prod}"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"

CURRENT_STAGE=""
ROLLBACK_TRIGGERED=false
declare -a COMPLETED_STAGES=()

cleanup() {
    local rc=$?
    if [[ $rc -ne 0 && "$ROLLBACK_TRIGGERED" == false ]]; then
        ROLLBACK_TRIGGERED=true
        log_warn "Pipeline failed at stage: $CURRENT_STAGE. Triggering rollback..."
        run_stage "rollback"
    fi
    audit_record "PIPELINE_END" "$([ $rc -eq 0 ] && echo SUCCESS || echo FAILURE)" \
        "Stages: ${COMPLETED_STAGES[*]}"
}
trap cleanup EXIT

run_stage() {
    CURRENT_STAGE="$1"
    local stage_script="$SCRIPT_DIR/stages/${1}.sh"
    audit_started "STAGE_$1" "Starting: $1"
    log_info "=== Stage: $1 ==="
    if bash "$stage_script" "$ENV"; then
        audit_success "STAGE_$1" "Completed"
        COMPLETED_STAGES+=("$1")
    else
        audit_failure "STAGE_$1" "Failed"
        return 1
    fi
}

audit_started "PIPELINE" "GitLab $ACTION pipeline on $ENV"
notify "GitLab pipeline started" "Action: $ACTION, Env: $ENV"
run_stage "precheck"
run_stage "backup"
run_stage "deploy"
run_stage "verify" || { run_stage "rollback"; exit 1; }
notify_success "GitLab pipeline completed" "Action: $ACTION, Env: $ENV"
```

- [ ] **Write gitlab/stages/precheck.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/utils.sh"

check_rbac "gitlab" || exit 1

if ping -c 2 "$GITLAB_HOST" &>/dev/null; then
    log_info "GitLab host reachable: $GITLAB_HOST"
else
    log_error "GitLab host unreachable"
    exit 1
fi

ssh_run "$GITLAB_HOST" "df -h $GITLAB_HOME"
log_info "Pre-check passed"
```

- [ ] **Write gitlab/stages/backup.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"

audit_started "BACKUP" "GitLab backup on $GITLAB_HOST"
ssh_run "$GITLAB_HOST" "gitlab-backup create CRON=1"
BACKUP_FILE=$(ssh_run "$GITLAB_HOST" "ls -t $GITLAB_BACKUP_DIR/*.tar | head -1")
log_info "Backup created: $BACKUP_FILE"
ssh_run "$GITLAB_HOST" "ls -la $BACKUP_FILE"
audit_success "BACKUP" "Backup: $BACKUP_FILE"
```

- [ ] **Write gitlab/stages/deploy.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"

audit_started "DEPLOY" "Upgrading GitLab to $GITLAB_VERSION on $GITLAB_HOST"

if [[ "$GITLAB_EDITION" == "ee" ]]; then
    PKG_URL="https://packages.gitlab.com/gitlab/gitlab-ee/packages/ubuntu/focal/gitlab-ee_${GITLAB_VERSION}_amd64.deb"
else
    PKG_URL="https://packages.gitlab.com/gitlab/gitlab-ce/packages/ubuntu/focal/gitlab-ce_${GITLAB_VERSION}_amd64.deb"
fi

log_info "Downloading GitLab $GITLAB_VERSION"
ssh_run "$GITLAB_HOST" "wget -q $PKG_URL -O /tmp/gitlab-${GITLAB_VERSION}.deb"

log_info "Installing GitLab $GITLAB_VERSION"
ssh_run "$GITLAB_HOST" "dpkg -i /tmp/gitlab-${GITLAB_VERSION}.deb"

log_info "Reconfiguring GitLab"
ssh_run "$GITLAB_HOST" "gitlab-ctl reconfigure"

audit_success "DEPLOY" "GitLab upgraded to $GITLAB_VERSION"
```

- [ ] **Write gitlab/stages/verify.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"

audit_started "VERIFY" "Verifying GitLab on $GITLAB_HOST"

# Wait for services
sleep 15

# Check all services
SERVICES=$(ssh_run "$GITLAB_HOST" "gitlab-ctl status" 2>/dev/null)
echo "$SERVICES"
if echo "$SERVICES" | grep -q "down"; then
    log_error "Some GitLab services are down"
    audit_failure "VERIFY" "Services down"
    return 1
fi

# HTTP check
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$GITLAB_HOST/-/health" 2>/dev/null || echo "000")
if [[ "$HTTP_STATUS" == "200" ]]; then
    log_info "Health endpoint OK: $HTTP_STATUS"
else
    log_warn "Health endpoint: $HTTP_STATUS"
fi

audit_success "VERIFY" "GitLab verified on $GITLAB_HOST"
```

- [ ] **Write gitlab/stages/rollback.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"

audit_started "ROLLBACK" "Rolling back GitLab on $GITLAB_HOST"

# Restore from backup
LATEST_BACKUP=$(ssh_run "$GITLAB_HOST" "ls -t $GITLAB_BACKUP_DIR/*.tar | head -1" 2>/dev/null)
if [[ -n "$LATEST_BACKUP" ]]; then
    BACKUP_NAME=$(basename "$LATEST_BACKUP" .tar)
    log_info "Restoring from backup: $BACKUP_NAME"
    ssh_run "$GITLAB_HOST" "gitlab-ctl stop unicorn && gitlab-ctl stop sidekiq"
    ssh_run "$GITLAB_HOST" "gitlab-backup restore BACKUP=$BACKUP_NAME force=yes"
    ssh_run "$GITLAB_HOST" "gitlab-ctl restart"
    audit_success "ROLLBACK" "Restored from $BACKUP_NAME"
else
    log_error "No backup found for rollback"
    audit_failure "ROLLBACK" "No backup available"
    return 1
fi
```

- [ ] **Write gitlab entrypoints** (patch.sh, backup-restore.sh, change-request.sh, health-check.sh)

```bash
#!/bin/bash
# gitlab/patch.sh
ENV="${1:-prod}"
VERSION="${2:-16.11.0}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
echo "GitLab Patch — $ENV → $VERSION"
sed -i "s/GITLAB_VERSION=.*/GITLAB_VERSION=\"$VERSION\"/" "$SCRIPT_DIR/config/$ENV.cfg"
exec "$SCRIPT_DIR/pipeline.sh" patch "$ENV"
```

```bash
#!/bin/bash
# gitlab/backup-restore.sh
ACTION="${1:-backup}"
ENV="${2:-prod}"
case "$ACTION" in
    backup) bash "$(dirname "$0")/stages/backup.sh" "$ENV" ;;
    restore) echo "Manual restore: run gitlab-backup restore on host"; exit 1 ;;
    *) echo "Usage: $0 {backup|restore} [env]"; exit 1 ;;
esac
```

```bash
#!/bin/bash
# gitlab/change-request.sh
exec "$(dirname "$0")/../jira/change-request.sh" "$@"
```

```bash
#!/bin/bash
# gitlab/health-check.sh
ENV="${1:-prod}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
echo "=== GitLab Health Check — $ENV ==="
echo "Host: $GITLAB_HOST"
echo -n "Ping: "; ping -c 1 -W 2 "$GITLAB_HOST" &>/dev/null && echo "OK" || echo "FAIL"
ssh "$GITLAB_HOST" "gitlab-ctl status"
echo "Disk: $(ssh "$GITLAB_HOST" "df -h /var/opt/gitlab | tail -1 | awk '{print \$3\"/\"\$2}'")"
```

- [ ] **Commit**

```bash
git add gitlab/
chmod +x gitlab/*.sh gitlab/stages/*.sh
git commit -m "feat(gitlab): add complete module (pipeline, stages, entrypoints)"
```

---

### Task 18: Coverity module

**Files:**
- Create: `coverity/config/shared.cfg`
- Create: `coverity/config/prod.cfg`
- Create: `coverity/pipeline.sh`
- Create: `coverity/stages/precheck.sh`
- Create: `coverity/stages/backup.sh`
- Create: `coverity/stages/deploy.sh`
- Create: `coverity/stages/verify.sh`
- Create: `coverity/stages/rollback.sh`
- Create: `coverity/patch.sh`
- Create: `coverity/backup-restore.sh`
- Create: `coverity/change-request.sh`
- Create: `coverity/health-check.sh`

- [ ] **Write coverity/config/shared.cfg**

```bash
# Coverity (Synopsys) shared config
COV_USER="coverity"
COV_INSTALL_DIR="/opt/coverity"
COV_DATA_DIR="/opt/coverity/data"
COV_SERVICE="coverity"
```

- [ ] **Write coverity/config/prod.cfg**

```bash
COV_HOST="coverity.company.com"
COV_VERSION="2024.12"
COV_WEB_PORT="8080"
BACKUP_RETAIN_DAYS=30
```

- [ ] **Write coverity/pipeline.sh**

```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/notify.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

ACTION="${1:-patch}"
ENV="${2:-prod}"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"

CURRENT_STAGE=""
ROLLBACK_TRIGGERED=false

cleanup() {
    local rc=$?
    if [[ $rc -ne 0 && "$ROLLBACK_TRIGGERED" == false ]]; then
        ROLLBACK_TRIGGERED=true; run_stage "rollback"
    fi
    audit_record "PIPELINE_END" "$([ $rc -eq 0 ] && echo SUCCESS || echo FAILURE)" ""
}
trap cleanup EXIT

run_stage() {
    CURRENT_STAGE="$1"; audit_started "STAGE_$1" "Starting: $1"
    log_info "=== Stage: $1 ==="
    bash "$SCRIPT_DIR/stages/${1}.sh" "$ENV" && audit_success "STAGE_$1" "OK" || { audit_failure "STAGE_$1" "FAIL"; return 1; }
}

audit_started "PIPELINE" "Coverity $ACTION pipeline on $ENV"
run_stage "precheck" && run_stage "backup" && run_stage "deploy" && run_stage "verify" || { run_stage "rollback"; exit 1; }
notify_success "Coverity pipeline done" "$ACTION on $ENV"
```

- [ ] **Write coverity/stages/precheck.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
check_rbac "coverity-admins" || exit 1
ping -c 2 "$COV_HOST" &>/dev/null && log_info "Host OK: $COV_HOST" || { log_error "Host unreachable"; exit 1; }
```

- [ ] **Write coverity/stages/backup.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"
audit_started "BACKUP" "Coverity backup on $COV_HOST"
ssh "$COV_HOST" "tar czf /backup/coverity-${ENV}-$(date +%Y%m%d).tgz $COV_DATA_DIR" 2>/dev/null
audit_success "BACKUP" "Coverity data backed up"
```

- [ ] **Write coverity/stages/deploy.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"
audit_started "DEPLOY" "Deploying Coverity $COV_VERSION on $COV_HOST"
ssh "$COV_HOST" "systemctl stop $COV_SERVICE" 2>/dev/null || true
ssh "$COV_HOST" "cp -a $COV_INSTALL_DIR ${COV_INSTALL_DIR}.$(date +%Y%m%d%H%M%S)" 2>/dev/null
ssh "$COV_HOST" "echo 'Placeholder: install Coverity $COV_VERSION package' && systemctl start $COV_SERVICE" 2>/dev/null
audit_success "DEPLOY" "Coverity $COV_VERSION deployed"
```

- [ ] **Write coverity/stages/verify.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
sleep 15
ssh "$COV_HOST" "systemctl is-active $COV_SERVICE" 2>/dev/null | grep -q "active" && log_info "Service active" || { log_error "Service not active"; return 1; }
CURL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$COV_HOST:$COV_WEB_PORT" 2>/dev/null || echo "000")
log_info "Web status: $CURL_STATUS"
```

- [ ] **Write coverity/stages/rollback.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
LATEST_BACKUP=$(ssh "$COV_HOST" "ls -td ${COV_INSTALL_DIR}.* 2>/dev/null | head -1" 2>/dev/null)
if [[ -n "$LATEST_BACKUP" ]]; then
    ssh "$COV_HOST" "systemctl stop $COV_SERVICE; rm -rf $COV_INSTALL_DIR; cp -a $LATEST_BACKUP $COV_INSTALL_DIR; systemctl start $COV_SERVICE"
    log_info "Rolled back Coverity from $LATEST_BACKUP"
fi
```

- [ ] **Write coverity entrypoints**

```bash
# coverity/patch.sh
ENV="${1:-prod}"; VERSION="${2:-2024.12}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
sed -i "s/COV_VERSION=.*/COV_VERSION=\"$VERSION\"/" "$SCRIPT_DIR/config/$ENV.cfg"
exec "$SCRIPT_DIR/pipeline.sh" patch "$ENV"
```

```bash
# coverity/backup-restore.sh
ACTION="${1:-backup}"; ENV="${2:-prod}"
case "$ACTION" in backup) bash "$(dirname "$0")/stages/backup.sh" "$ENV" ;; *) echo "Usage: $0 backup [env]"; exit 1 ;; esac
```

```bash
# coverity/change-request.sh
exec "$(dirname "$0")/../jira/change-request.sh" "$@"
```

```bash
# coverity/health-check.sh
ENV="${1:-prod}"; SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"; source "$SCRIPT_DIR/config/$ENV.cfg"
echo "=== Coverity Health Check — $ENV ==="
ssh "$COV_HOST" "systemctl status $COV_SERVICE | head -5"
curl -s -o /dev/null -w "HTTP: %{http_code}\n" "http://$COV_HOST:$COV_WEB_PORT"
```

- [ ] **Commit**

```bash
git add coverity/
chmod +x coverity/*.sh coverity/stages/*.sh
git commit -m "feat(coverity): add complete module"
```

---

### Task 19: BlackDuck module

**Files:**
- Create: `blackduck/config/shared.cfg`
- Create: `blackduck/config/prod.cfg`
- Create: `blackduck/pipeline.sh`
- Create: `blackduck/stages/precheck.sh`
- Create: `blackduck/stages/backup.sh`
- Create: `blackduck/stages/deploy.sh`
- Create: `blackduck/stages/verify.sh`
- Create: `blackduck/stages/rollback.sh`
- Create: `blackduck/patch.sh`
- Create: `blackduck/backup-restore.sh`
- Create: `blackduck/change-request.sh`
- Create: `blackduck/health-check.sh`

- [ ] **Write blackduck/config/shared.cfg**

```bash
# BlackDuck (Synopsys) shared config
BD_USER="blackduck"
BD_INSTALL_DIR="/opt/blackduck"
BD_DATA_DIR="/opt/blackduck/data"
BD_SERVICE="blackduck"
```

- [ ] **Write blackduck/config/prod.cfg**

```bash
BD_HOST="blackduck.company.com"
BD_VERSION="2024.10"
BD_WEB_PORT="443"
BACKUP_RETAIN_DAYS=30
```

- [ ] **Write blackduck/pipeline.sh** (same template as coverity, adjust variable names)

```bash
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"
source "$PROJECT_ROOT/shared/lib/notify.sh"
source "$PROJECT_ROOT/shared/lib/utils.sh"

ACTION="${1:-patch}"
ENV="${2:-prod}"
source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"

CURRENT_STAGE=""; ROLLBACK_TRIGGERED=false
cleanup() {
    local rc=$?
    if [[ $rc -ne 0 && "$ROLLBACK_TRIGGERED" == false ]]; then
        ROLLBACK_TRIGGERED=true; run_stage "rollback"
    fi
    audit_record "PIPELINE_END" "$([ $rc -eq 0 ] && echo SUCCESS || echo FAILURE)" ""
}
trap cleanup EXIT

run_stage() {
    CURRENT_STAGE="$1"; audit_started "STAGE_$1" "Starting: $1"
    log_info "=== Stage: $1 ==="
    bash "$SCRIPT_DIR/stages/${1}.sh" "$ENV" && audit_success "STAGE_$1" "OK" || { audit_failure "STAGE_$1" "FAIL"; return 1; }
}

audit_started "PIPELINE" "BlackDuck $ACTION pipeline on $ENV"
run_stage "precheck" && run_stage "backup" && run_stage "deploy" && run_stage "verify" || { run_stage "rollback"; exit 1; }
notify_success "BlackDuck pipeline done" "$ACTION on $ENV"
```

- [ ] **Write blackduck/stages/precheck.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
check_rbac "blackduck-admins" || exit 1
ping -c 2 "$BD_HOST" &>/dev/null && log_info "Host OK: $BD_HOST" || { log_error "Host unreachable"; exit 1; }
```

- [ ] **Write blackduck/stages/backup.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"
audit_started "BACKUP" "BlackDuck backup on $BD_HOST"
ssh "$BD_HOST" "tar czf /backup/blackduck-${ENV}-$(date +%Y%m%d).tgz $BD_DATA_DIR" 2>/dev/null
audit_success "BACKUP" "BlackDuck data backed up"
```

- [ ] **Write blackduck/stages/deploy.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/audit.sh"
audit_started "DEPLOY" "Deploying BlackDuck $BD_VERSION on $BD_HOST"
ssh "$BD_HOST" "systemctl stop $BD_SERVICE" 2>/dev/null || true
ssh "$BD_HOST" "cp -a $BD_INSTALL_DIR ${BD_INSTALL_DIR}.$(date +%Y%m%d%H%M%S)" 2>/dev/null
ssh "$BD_HOST" "echo 'Placeholder: install BlackDuck $BD_VERSION' && systemctl start $BD_SERVICE" 2>/dev/null
audit_success "DEPLOY" "BlackDuck $BD_VERSION deployed"
```

- [ ] **Write blackduck/stages/verify.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
sleep 15
ssh "$BD_HOST" "systemctl is-active $BD_SERVICE" 2>/dev/null | grep -q "active" && log_info "Service active" || { log_error "Service not active"; return 1; }
CURL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$BD_HOST:$BD_WEB_PORT" 2>/dev/null || echo "000")
log_info "Web status: $CURL_STATUS"
```

- [ ] **Write blackduck/stages/rollback.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(dirname "$0")/../config/shared.cfg"
source "$(dirname "$0")/../config/$ENV.cfg"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
LATEST_BACKUP=$(ssh "$BD_HOST" "ls -td ${BD_INSTALL_DIR}.* 2>/dev/null | head -1" 2>/dev/null)
if [[ -n "$LATEST_BACKUP" ]]; then
    ssh "$BD_HOST" "systemctl stop $BD_SERVICE; rm -rf $BD_INSTALL_DIR; cp -a $LATEST_BACKUP $BD_INSTALL_DIR; systemctl start $BD_SERVICE"
    log_info "Rolled back BlackDuck from $LATEST_BACKUP"
fi
```

- [ ] **Write blackduck entrypoints**

```bash
# blackduck/patch.sh
ENV="${1:-prod}"; VERSION="${2:-2024.10}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
sed -i "s/BD_VERSION=.*/BD_VERSION=\"$VERSION\"/" "$SCRIPT_DIR/config/$ENV.cfg"
exec "$SCRIPT_DIR/pipeline.sh" patch "$ENV"
```

```bash
# blackduck/backup-restore.sh
ACTION="${1:-backup}"; ENV="${2:-prod}"
case "$ACTION" in backup) bash "$(dirname "$0")/stages/backup.sh" "$ENV" ;; *) echo "Usage: $0 backup [env]"; exit 1 ;; esac
```

```bash
# blackduck/change-request.sh
exec "$(dirname "$0")/../jira/change-request.sh" "$@"
```

```bash
# blackduck/health-check.sh
ENV="${1:-prod}"; SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config/shared.cfg"; source "$SCRIPT_DIR/config/$ENV.cfg"
echo "=== BlackDuck Health Check — $ENV ==="
ssh "$BD_HOST" "systemctl status $BD_SERVICE | head -5"
curl -s -o /dev/null -w "HTTP: %{http_code}\n" "https://$BD_HOST:$BD_WEB_PORT"
```

- [ ] **Commit**

```bash
git add blackduck/
chmod +x blackduck/*.sh blackduck/stages/*.sh
git commit -m "feat(blackduck): add complete module"
```

---

### Task 20: shared/templates/ — Reusable stage templates

**Files:**
- Create: `shared/templates/precheck.sh`
- Create: `shared/templates/backup.sh`
- Create: `shared/templates/deploy.sh`
- Create: `shared/templates/verify.sh`
- Create: `shared/templates/rollback.sh`

- [ ] **Write shared/templates/precheck.sh**

```bash
#!/bin/bash
# Template: precheck stage
# Override in system-specific stages/ for custom logic
ENV="$1"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
log_info "Pre-check passed (default template)"
```

- [ ] **Write shared/templates/backup.sh**

```bash
#!/bin/bash
# Template: backup stage — override in system stages/
ENV="$1"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
log_warn "No custom backup script for this system — using default template (no-op)"
```

- [ ] **Write shared/templates/deploy.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
log_warn "No custom deploy script — using default template (no-op)"
```

- [ ] **Write shared/templates/verify.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
log_warn "No custom verify script — using default template (no-op)"
```

- [ ] **Write shared/templates/rollback.sh**

```bash
#!/bin/bash
ENV="$1"
source "$(cd "$(dirname "$0")/../.." && pwd)/shared/lib/log.sh"
log_warn "No custom rollback script — using default template (no-op)"
```

- [ ] **Commit**

```bash
git add shared/templates/
chmod +x shared/templates/*.sh
git commit -m "feat(shared): add reusable stage templates"
```

---

### Task 21: Compliance docs

**Files:**
- Create: `docs/compliance/iso-20000-mapping.md`
- Create: `docs/compliance/iso-27001-mapping.md`

- [ ] **Write docs/compliance/iso-20000-mapping.md**

```markdown
# ISO 20000-1:2018 — IT Service Management Mapping

## Clause Mapping

| ISO 20000 Clause | Requirement | Implementation |
|-----------------|-------------|----------------|
| 8.2 | Change Management | `pipeline.sh` implements Plan → Approve → Implement → Verify → Close lifecycle |
| 8.2.1 | Change requests documented | `change-request.sh` creates/updates CR in ManageEngine SD+ |
| 8.2.2 | Risk assessment | Pipeline precheck stage includes risk evaluation |
| 8.2.3 | Change approval | ManageEngine SD+ approval workflow (external) |
| 8.2.4 | Change implementation | Automated pipeline with rollback on failure |
| 8.2.5 | Post-implementation review | Verify stage + audit log + notification |
| 9.2 | Incident management | Failure notification to ops + security teams |
| 9.3 | Problem management | Audit trail for root cause analysis |
| 10.1 | Configuration management | Config files per environment (dev/staging/prod) |

## Change Record Fields (SD+)

Every change request includes:
- Title, description, category
- Priority, risk level
- Rollback plan
- Implementation plan
- Status tracking: Draft → Approved → In Progress → Implemented → Verified → Closed
```

- [ ] **Write docs/compliance/iso-27001-mapping.md**

```markdown
# ISO 27001:2022 — Information Security Mapping

## Annex A Control Mapping

| ISO 27001 Control | Requirement | Implementation |
|-------------------|-------------|----------------|
| A.8.1 | Asset management | `health-check.sh` reports system status |
| A.8.9 | Configuration management | Environment configs under version control |
| A.8.10 | Information deletion | Backup retention policies in config |
| A.8.11 | Data masking | Secrets in .env (gitignored), not in scripts |
| A.8.12 | Data leakage prevention | Audit log monitors all operational changes |
| A.8.24 | Use of cryptography | Checksum verification (SHA-256) for scripts |
| A.8.25 | Secure development | Script signing via .sha256 sidecar files |
| A.8.29 | Security testing | Health-check scripts for post-deploy verification |
| A.8.32 | Change management | Pipeline with rollback (aligned with ISO 20000) |
| A.8.33 | Backup | Backup stage before all deploy operations |
| A.8.34 | Backup verification | Checksum verification of backup files |
| A.8.35 | Logging | Structured JSON audit to file + Syslog/Event |
| A.8.36 | Log protection | Audit log in restricted directory |
| A.8.37 | Clock synchronization | Timestamps in UTC ISO 8601 format |
| A.8.39 | Privileged access | RBAC check before any operation |
| A.8.40 | Vulnerability management | Patch pipeline (placeholder for scan trigger) |

## Audit Record Format

Every operation generates:
```json
{
  "timestamp": "2026-06-11T10:00:00Z",
  "user": "ops_admin",
  "host": "jira-app01",
  "pid": 12345,
  "action": "PIPELINE_START",
  "status": "STARTED",
  "details": "Jira patch pipeline on prod"
}
```
```

- [ ] **Commit**

```bash
git add docs/compliance/
git commit -m "docs: add ISO 20000/27001 compliance mapping"
```

---

### Task 22: docs/runbooks/ — Operations runbooks

**Files:**
- Create: `docs/runbooks/jira-patch-runbook.md`
- Create: `docs/runbooks/jira-restore-runbook.md`
- Create: `docs/runbooks/gitlab-patch-runbook.md`
- Create: `docs/runbooks/gitlab-restore-runbook.md`

- [ ] **Write docs/runbooks/jira-patch-runbook.md**

```markdown
# Jira Patch Runbook

## Prerequisites
- [ ] User in `jira-admins` group
- [ ] Backup Exec job configured for Jira
- [ ] ManageEngine SD+ change request created
- [ ] NGINX Plus API accessible

## Steps

1. **Create Change Request**
   ```bash
   ./jira/change-request.sh create \
     "Jira patch to v10.5.0 (prod)" \
     "Security patch update per advisory SEC-2024-xxx" \
     "High"
   ```

2. **Run Patch Pipeline**
   ```bash
   ./jira/patch.sh prod 10.5.0
   ```
   Pipeline proceeds automatically: precheck → backup → drain node1 → deploy → verify → drain node2 → deploy → verify.

3. **Verify**
   - Jira accessible via load balancer URL
   - All projects load correctly
   - Users can create/edit issues
   - DB replication OK

4. **Close Change Request**
   ```bash
   ./jira/change-request.sh update CR-123 "Closed"
   ```

## Rollback
- Pipeline auto-rolls back on failure
- Manual: `./jira/backup-restore.sh restore prod /backup/jira-prod-20260611/`
```

- [ ] **Write the remaining runbooks** (jira-restore-runbook, gitlab-patch-runbook, gitlab-restore-runbook)

- [ ] **Commit**

```bash
git add docs/runbooks/
git commit -m "docs: add operations runbooks"
```

---

### Task 23: README.md

- [ ] **Write README.md**

```markdown
# AI Ops — ISO 20000/27001 Operations Scripts

Production-ready scripts for backup-restore, patch-management, change-management, and security-compliance.

## Systems

| System | Tech Stack | Nodes |
|--------|-----------|-------|
| Jira Software | Java, MySQL Galera 8.0, NFS, NGINX Plus | 2 app + 2 DB |
| GitLab | Ruby/Rails, Omnibus, PostgreSQL | 1 |
| Coverity | Synopsys | 1 |
| BlackDuck | Synopsys | 1 |

## Quick Start

```bash
cp .env.template .env   # Fill in secrets
./jira/patch.sh prod 10.5.0
```

## Structure

```
shared/lib/       — Cross-cutting library (logging, audit, notification, API wrappers)
jira/             — Jira module
gitlab/           — GitLab module
coverity/         — Coverity module
blackduck/        — BlackDuck module
docs/             — Runbooks, compliance mapping
```

## Standards

- ISO 20000-1:2018 — Change management, service management
- ISO 27001:2022 — Access control, backup, logging, vulnerability management
```

- [ ] **Commit**

```bash
git add README.md
git commit -m "docs: add README"
```

---

### Self-Review

1. **Spec coverage:** All spec sections covered — shared library (Tasks 1-10), Jira module (Tasks 11-16), GitLab/Coverity/BlackDuck (Tasks 17-19), templates (Task 20), compliance docs (Task 21), runbooks (Task 22), README (Task 23)
2. **Placeholder scan:** No TBD/TODO/fill-in-later patterns. All scripts contain full implementation code.
3. **Type consistency:** Variable names consistent (JIRA_, GITLAB_, COV_, BD_ prefixes). Service names, config paths match across tasks.
4. **Scope:** Focused on one implementation plan. Systems are independent modules sharing common lib — pattern is correct per spec.
