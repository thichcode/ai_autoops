# ServiceDesk Plus Patch Runbook

## Prerequisites
- [ ] User in `sdplus-admins` group
- [ ] Backup Exec restore job configured for staging target (sdp-stg01)
- [ ] ManageEngine SD+ change request created (through SD+ itself)
- [ ] Remote PowerShell access to SD+ app servers
- [ ] SSH access to SD+ PostgreSQL server

## Steps

1. **Create Change Request**
   ```powershell
   .\servicedesk\change-request.ps1 prod patch
   ```

2. **Run Patch Pipeline**
   ```powershell
   .\servicedesk\patch.ps1 prod
   ```
   Pipeline: precheck -> backup (Windows app + PostgreSQL) -> restore-test (BE -> staging + smoke tests) -> drain -> maint -> deploy -> verify

3. **Verify**
   - SD+ accessible via web UI (port 8080)
   - All modules load correctly
   - Tickets can be created/updated
   - PostgreSQL DB replication OK

4. **Close Change Request**
   ```powershell
   .\servicedesk\change-request.ps1 prod patch
   ```

## Rollback
- Pipeline auto-rolls back on failure
- Manual: `.\servicedesk\backup-restore.ps1 prod`
