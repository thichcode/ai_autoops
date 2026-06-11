#!/bin/bash
set -euo pipefail
ENV="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"; PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/config/shared.cfg" "$SCRIPT_DIR/config/$ENV.cfg"
source "$PROJECT_ROOT/shared/lib/log.sh" "$PROJECT_ROOT/shared/lib/audit.sh"
audit_started "ROLLBACK" "Rolling back SonarQube"
ssh_run "$SONAR_NODE" "systemctl stop $SONAR_SERVICE" || true
ssh_run "$SONAR_NODE" "[[ -d ${BACKUP_BASE}/sonar-previous ]] && cp -a ${BACKUP_BASE}/sonar-previous/* $SONAR_HOME/" || true
ssh_run "$SONAR_NODE" "systemctl start $SONAR_SERVICE" || true
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$SONAR_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "ROLLBACK" "SonarQube rollback completed"
