# Prometheus + Grafana Restore Runbook

## Steps
1. `./prometheus-grafana/backup-restore.sh prod` — enter backup date
2. Smoke tests (5): Prometheus reachable, Prometheus ready, Grafana reachable, Grafana health, Alertmanager reachable
3. Report: `/backup/reports/restore-test-pg-*.md`
