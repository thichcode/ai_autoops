# Confluence Restore Runbook

## Purpose
Restore Confluence from Backup Exec to staging environment for verification, or restore production from VM snapshot.

## Steps

### Restore to Staging (Test)
1. **Run restore-test (Backup Exec -> staging)**
   ```bash
   ./confluence/backup-restore.sh prod
   ```

2. **When prompted**, enter backup date (YYYY-MM-DD) or press Enter for latest

3. **Smoke tests run automatically:**
   - Node reachable after restore
   - Confluence service active
   - HTTP 200 on /status
   - DB reachable

4. **Report** generated at `/backup/reports/restore-test-confluence-*.md`

### Restore Production (from VM snapshot)
- Production Confluence uses VM snapshots (vSphere)
- Trigger via vSphere console — not automated
