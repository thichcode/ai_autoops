# ELK Stack Patch Runbook

## Prerequisites
- [ ] User in `elk-admins` group
- [ ] Backup Exec restore job configured for staging
- [ ] SD+ change request created

## Steps
1. `./elk/change-request.sh prod patch`
2. `./elk/patch.sh prod` — precheck -> backup (ES snapshot + Kibana export) -> restore-test -> stop LS/ES/KB -> deploy -> verify
3. Verify: ES cluster health, indices, Kibana UI, Logstash pipelines

## Rollback
- Restore ES snapshot + Kibana saved objects
