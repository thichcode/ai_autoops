#!/bin/bash
set -euo pipefail
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
        payload=$(jq -n --arg subject "$subject" --arg message "$message" \
            '{text: ("*[" + $subject + "]*\n" + $message)}')
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
