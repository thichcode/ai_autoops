#!/bin/bash
# deploy.sh — Deploy Jira patch version on current node

set -euo pipefail

ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/config/shared.cfg"
source "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh"
source "$PROJECT_ROOT/shared/lib/audit.sh"

NODE="${CURRENT_NODE:?CURRENT_NODE not set}"
audit_started "DEPLOY" "Deploying Jira $JIRA_VERSION on $NODE"

DEPLOY_DIR="${JIRA_INSTALL_DIR}-${JIRA_VERSION}"
BACKUP_DIR="${BACKUP_BASE}/jira-${ENV}-${JIRA_VERSION}-backup"

log_info "Backing up current installation on $NODE"
ssh_run "$NODE" "cp -a $JIRA_INSTALL_DIR ${BACKUP_DIR}" || {
    log_error "Failed to backup current install on $NODE"
    return 1
}

DIST_FILE="atlassian-jira-software-${JIRA_VERSION}.tar.gz"
DIST_URL="${JIRA_DIST_URL/\{version\}/$JIRA_VERSION}"

ssh_run "$NODE" "if [[ ! -f /tmp/$DIST_FILE ]]; then wget -q $DIST_URL -O /tmp/$DIST_FILE; fi"

ssh_run "$NODE" "tar xzf /tmp/$DIST_FILE -C /opt/atlassian/"
ssh_run "$NODE" "rm -f $JIRA_INSTALL_DIR && ln -sf $DEPLOY_DIR $JIRA_INSTALL_DIR"

audit_success "DEPLOY" "Jira $JIRA_VERSION deployed on $NODE"
log_info "Deployment completed on $NODE"
