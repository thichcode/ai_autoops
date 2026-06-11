# Confluence Patch Runbook

## Prerequisites
- [ ] User in `confluence-admins` group
- [ ] Backup Exec restore job configured for staging target (confluence-stg01)
- [ ] ManageEngine SD+ change request created
- [ ] NGINX Plus API accessible

## Steps

1. **Create Change Request**
   ```bash
   ./confluence/change-request.sh prod patch
   ```

2. **Run Patch Pipeline**
   ```bash
   ./confluence/patch.sh prod
   ```
   Pipeline: precheck -> backup -> restore-test (BE -> staging + smoke tests) -> drain node1 -> deploy -> verify -> drain node2 -> deploy -> verify.

3. **Verify**
   - Confluence accessible via load balancer URL
   - All spaces load correctly
   - Users can create/edit pages
   - DB replication OK

4. **Close Change Request**
   ```bash
   ./confluence/change-request.sh prod patch
   ```

## Rollback
- Pipeline auto-rolls back on failure
- Manual: `./confluence/backup-restore.sh prod`
