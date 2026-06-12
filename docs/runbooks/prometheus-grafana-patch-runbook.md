# Prometheus + Grafana Patch Runbook

## Prerequisites
- [ ] User in `pg-admins` group
- [ ] Backup Exec restore job configured for staging
- [ ] SD+ change request created

## Steps
1. `./prometheus-grafana/change-request.sh prod patch`
2. `./prometheus-grafana/patch.sh prod` — precheck -> backup (TSDB + config -> dashboards) -> restore-test -> drain Grafana LB -> stop each -> deploy each -> verify -> re-enable LB
3. Verify: Prometheus /-/ready, Grafana /api/health, Alertmanager reachable

## Rollback
- Restore Prometheus TSDB snapshot + Grafana data dir
