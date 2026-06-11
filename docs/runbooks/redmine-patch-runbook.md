# Redmine Patch Runbook

## Prerequisites
- [ ] User in `redmine-admins` group
- [ ] Backup Exec restore job configured for staging
- [ ] Change request created

## Steps

1. **Create Change Request** `./redmine/change-request.sh prod patch`

2. **Run Patch Pipeline** `./redmine/patch.sh prod`
   Pipeline: precheck -> backup (DB + files) -> restore-test -> drain node -> stop -> deploy -> verify -> re-enable

3. **Verify**
   - Redmine UI accessible
   - Projects and issues display correctly
   - File attachments accessible

## Rollback
- Pipeline auto-rolls back
- Restore DB dump + files
