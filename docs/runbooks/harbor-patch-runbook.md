# Harbor Patch Runbook

## Prerequisites
- [ ] User in `harbor-admins` group
- [ ] Backup Exec restore job configured for staging
- [ ] SD+ change request created

## Steps
1. `./harbor/change-request.sh prod patch`
2. `./harbor/patch.sh prod` — precheck -> backup (DB + data) -> restore-test -> drain LB -> docker-compose down -> install -> verify -> re-enable LB
3. Verify: API ping, project list, docker login/push

## Rollback
- Pipeline auto-rolls back
- Restore DB + previous data
