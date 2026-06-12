#!/bin/bash
set -euo pipefail; ENV="$1"
SD="$(cd "$(dirname "$0")/.." && pwd)"; PR="$(cd "$SD/.." && pwd)"
source "$SD/config/shared.cfg" "$SD/config/$ENV.cfg" "$PR/shared/lib/log.sh" "$PR/shared/lib/audit.sh"
audit_started "DEPLOY" "Deploying ELK $ELK_VERSION"
ES_REPO="https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${ELK_VERSION}-linux-x86_64.tar.gz"
KB_REPO="https://artifacts.elastic.co/downloads/kibana/kibana-${ELK_VERSION}-linux-x86_64.tar.gz"
LS_REPO="https://artifacts.elastic.co/downloads/logstash/logstash-${ELK_VERSION}-linux-x86_64.tar.gz"
for node in "${ES_NODES[@]}"; do
    ssh_run "$node" "wget -q $ES_REPO -O /tmp/elasticsearch.tar.gz && tar xzf /tmp/elasticsearch.tar.gz -C /usr/share/ && rm -f $ES_HOME && ln -sf /usr/share/elasticsearch-${ELK_VERSION} $ES_HOME" || log_warn "ES deploy on $node failed"
done
ssh_run "$KB_NODE" "wget -q $KB_REPO -O /tmp/kibana.tar.gz && tar xzf /tmp/kibana.tar.gz -C /usr/share/ && rm -f $KB_HOME && ln -sf /usr/share/kibana-${ELK_VERSION} $KB_HOME" || log_warn "Kibana deploy failed"
ssh_run "$LS_NODE" "wget -q $LS_REPO -O /tmp/logstash.tar.gz && tar xzf /tmp/logstash.tar.gz -C /usr/share/ && rm -f $LS_HOME && ln -sf /usr/share/logstash-${ELK_VERSION} $LS_HOME" || log_warn "Logstash deploy failed"
audit_success "DEPLOY" "ELK $ELK_VERSION deployed"
