#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "ROLLBACK" "Rolling back ELK"
for node in "${ES_NODES[@]}"; do ssh_run "$node" "systemctl stop $ES_SERVICE" || true; done
ssh_run "$KB_NODE" "systemctl stop $KB_SERVICE" || true
ssh_run "$LS_NODE" "systemctl stop $LS_SERVICE" || true
# Restore ES snapshot
ES_NODE="${ES_NODES[0]}"
LATEST=$(ssh_run "$ES_NODE" "ls -t $ES_SNAPSHOT_DIR 2>/dev/null | head -1" || true)
[[ -n "$LATEST" ]] && ssh_run "$ES_NODE" "curl -s -X POST 'http://localhost:${ES_PORT}/_snapshot/backup_repo/${LATEST}/_restore?wait_for_completion=true'" 2>/dev/null || log_warn "ES snapshot restore skipped"
for node in "${ES_NODES[@]}"; do ssh_run "$node" "systemctl start $ES_SERVICE" || true; done
sleep 20
ssh_run "$KB_NODE" "systemctl start $KB_SERVICE" || true
ssh_run "$LS_NODE" "systemctl start $LS_SERVICE" || true
local NETRC=$(mktemp); echo "default login $NGINX_PLUS_API_USER password $NGINX_PLUS_API_PASS" > "$NETRC"; chmod 600 "$NETRC"
curl -s -X PATCH -d '{"weight": 1}' "$NGINX_PLUS_API/6/upstreams/$NGINX_UPSTREAM_NAME/servers/$KB_NODE" --netrc-file "$NETRC" || true
rm -f "$NETRC"; audit_success "ROLLBACK" "ELK rollback completed"
