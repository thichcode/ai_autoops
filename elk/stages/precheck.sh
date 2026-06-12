#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/utils.sh"
check_rbac "elk-admins" || exit 1
for node in "${ES_NODES[@]}"; do
    ping -c 2 "$node" &>/dev/null && log_info "ES node OK: $node" || { log_error "ES node unreachable: $node"; exit 1; }
    curl -s "http://${node}:${ES_PORT}/_cluster/health" 2>/dev/null | grep -q 'status' && log_info "ES cluster accessible on $node" || log_warn "ES not responding on $node"
done
ping -c 2 "$KB_NODE" &>/dev/null && log_info "Kibana OK: $KB_NODE" || log_warn "Kibana unreachable"
ping -c 2 "$LS_NODE" &>/dev/null && log_info "Logstash OK: $LS_NODE" || log_warn "Logstash unreachable"
log_info "All pre-checks passed"
