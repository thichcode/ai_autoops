# Jira Restore Runbook

## Prerequisites
- [ ] Backup Exec job with valid restore point
- [ ] All Jira nodes stopped
- [ ] DB access credentials available

## Steps

1. **Restore from Backup Exec**
   Trigger restore from latest BE job or run:
   ```bash
   ./jira/backup-restore.sh restore prod /backup/jira-prod-20260611/
   ```

2. **Restore Database**
   ```bash
   zcat /backup/jira-prod-20260611/jiradb.sql.gz | mysql -u jiradb -p jiradb
   ```

3. **Verify**
   ```bash
   ./jira/health-check.sh prod
   ```

4. **Update Change Request**
   ```bash
   ./jira/change-request.sh update CR-123 "Closed"
   ```
