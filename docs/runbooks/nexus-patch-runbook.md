# Nexus Patch Runbook

## Prerequisites
- [ ] User in `nexus-admins` group
- [ ] Backup Exec restore job configured for staging
- [ ] Change request created

## Steps

1. **Create Change Request** `./nexus/change-request.sh prod patch`

2. **Run Patch Pipeline** `./nexus/patch.sh prod`
   Pipeline: precheck -> backup (blobs + data) -> restore-test -> drain LB -> stop -> deploy -> verify -> re-enable LB

3. **Verify**
   - Nexus UI accessible on 8081
   - Repositories browsable
   - Maven/npm/Docker pulls work

## Rollback
- Pipeline auto-rolls back
- Restore nexus-data + previous install
