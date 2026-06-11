# Jira Patch Runbook

## Prerequisites
- [ ] User in `jira-admins` group
- [ ] Backup Exec restore job configured for staging target (jira-stg01)
- [ ] ManageEngine SD+ change request created
- [ ] NGINX Plus API accessible

## Steps

1. **Create Change Request**
   ```bash
   ./jira/change-request.sh create \
     "Jira patch to v10.5.0 (prod)" \
     "Security patch update per advisory SEC-2024-xxx" \
     "High"
   ```

2. **Run Patch Pipeline**
   ```bash
   ./jira/patch.sh prod 10.5.0
   ```
   Pipeline: precheck -> backup -> restore-test (BE -> staging + smoke tests) -> drain node1 -> deploy -> verify -> drain node2 -> deploy -> verify.
   Restore-test generates formal report at `/backup/reports/restore-test-*.md`.

3. **Verify**
   - Jira accessible via load balancer URL
   - All projects load correctly
   - Users can create/edit issues
   - DB replication OK

4. **Close Change Request**
   ```bash
   ./jira/change-request.sh update CR-123 "Closed"
   ```

## Rollback
- Pipeline auto-rolls back on failure
- Manual: `./jira/backup-restore.sh restore prod /backup/jira-prod-20260611/`
