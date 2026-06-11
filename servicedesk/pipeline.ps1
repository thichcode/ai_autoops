#!/usr/bin/env pwsh
# ServiceDesk Plus pipeline orchestrator (Windows app + PostgreSQL DB)
param([string]$Action="patch", [string]$Env="prod")
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
. "$ProjectRoot/shared/lib/log.ps1"
. "$ProjectRoot/shared/lib/audit.ps1"
. "$ProjectRoot/shared/lib/notify.ps1"
. "$ScriptDir/config/shared.cfg"
. "$ScriptDir/config/$Env.cfg"

$CurrentStage = ""; $CompletedStages = @(); $RollbackTriggered = $false

function Invoke-Stage {
    param([string]$Stage)
    $script:CurrentStage = $Stage
    $path = Join-Path $ScriptDir "stages" "$Stage.ps1"
    if (-not (Test-Path $path)) { $path = Join-Path $ProjectRoot "shared\templates" "$Stage.ps1" }
    if (-not (Test-Path $path)) { Write-Log ERROR "Stage not found: $Stage"; return $false }
    Write-Log INFO "=== Stage: $Stage ==="
    Audit-Started "STAGE_$Stage" "Starting: $Stage" $Env
    try {
        & $path $Env $Action
        Audit-Success "STAGE_$Stage" "Completed" $Env
        $script:CompletedStages += $Stage
        return $true
    } catch {
        Audit-Failure "STAGE_$Stage" "$($_.Exception.Message)" $Env
        return $false
    }
}

try {
    Audit-Started "PIPELINE" "ServiceDesk $Action pipeline on $Env" $Env
    Notify "ServiceDesk pipeline started" "Action: $Action, Env: $Env"
    if (-not (Invoke-Stage "precheck")) { throw "Precheck failed" }
    if (-not (Invoke-Stage "backup")) { throw "Backup failed" }
    if (-not (Invoke-Stage "restore-test")) { throw "Restore test failed" }
    if ($Action -eq "patch") {
        foreach ($node in $SD_APP_NODES) {
            Write-Log INFO "Processing node: $node"
            $env:CURRENT_NODE = $node
            if (-not (Invoke-Stage "drain")) { throw "Drain failed" }
            if (-not (Invoke-Stage "maint")) { throw "Maintenance failed" }
            if (-not (Invoke-Stage "deploy")) { throw "Deploy failed" }
            if (-not (Invoke-Stage "verify")) { throw "Verify failed" }
        }
    }
    Notify-Success "ServiceDesk pipeline completed" "Action: $Action, Env: $Env"
} catch {
    if (-not $RollbackTriggered) {
        $script:RollbackTriggered = $true
        Notify-Failure "ServiceDesk pipeline failed at $CurrentStage" $_.Exception.Message
        Invoke-Stage "rollback"
    }
} finally {
    $status = if ($RollbackTriggered) { "FAILURE" } else { "SUCCESS" }
    Audit-Record "PIPELINE_END" $status "Stages: $($CompletedStages -join ', ')" $Env
}
