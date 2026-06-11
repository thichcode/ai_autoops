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
    Audit-Success "SD_UPDATE_CR" "Updated CR $CrId -> $Status"
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
