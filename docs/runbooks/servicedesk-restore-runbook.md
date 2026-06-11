# ServiceDesk Plus Restore Runbook

## Purpose
Restore ServiceDesk Plus (Windows app + PostgreSQL DB) from Backup Exec to staging.

## Steps

### Restore to Staging (Test)
1. **Run restore-test (Backup Exec -> staging)**
   ```powershell
   .\servicedesk\backup-restore.ps1 prod
   ```

2. **When prompted**, enter backup date (YYYY-MM-DD) or press Enter for latest

3. **Smoke tests run automatically:**
   - Node reachable after restore
   - SD+ service running
   - HTTP accessible on port 8080
   - PostgreSQL DB reachable

4. **Report** generated at `/backup/reports/restore-test-sdplus-*.md`

### Notes
- Windows app restore uses Backup Exec to staging server
- PostgreSQL DB restore uses pg_dump / pg_restore on Linux
- Production VM-level restore is handled separately via vSphere
