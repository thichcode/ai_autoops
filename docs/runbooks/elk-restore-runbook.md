# ELK Restore Runbook

## Steps
1. `./elk/backup-restore.sh prod` — enter backup date
2. Smoke tests (5): ES reachable, ES cluster, Kibana API, Logstash service, indices count
3. Report: `/backup/reports/restore-test-elk-*.md`
