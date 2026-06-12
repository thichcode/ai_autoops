# AWX Patch Runbook

## Prerequisites
- [ ] User in `awx-admins` group
- [ ] Backup Exec restore job configured for staging
- [ ] SD+ change request created

## Steps
1. `./awx/change-request.sh prod patch`
2. `./awx/patch.sh prod` — precheck -> backup (DB + projects) -> restore-test -> drain LB -> docker-compose down -> install -> verify -> re-enable LB
3. Verify: HTTPS 200, AWX web UI, container status, DB reachable

## Rollback
- Restore DB dump + docker-compose up
