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
        try {
            $body = @{ text = "*[$Subject]*`n$Message" } | ConvertTo-Json
            Invoke-RestMethod -Uri $Script:NotifySlackUrl -Method Post -Body $body -ContentType "application/json" -ErrorAction Stop
        } catch {
            Write-LogError "Slack notification failed: $_"
        }
    }
}

function Send-Success   { Send-Notification -Subject "[SUCCESS] $($args[0])" -Message $args[1] }
function Send-Failure   { Send-Notification -Subject "[FAILURE] $($args[0])" -Message $args[1] }
function Send-Warning   { Send-Notification -Subject "[WARNING] $($args[0])" -Message $args[1] }
