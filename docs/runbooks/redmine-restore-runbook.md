# Redmine Restore Runbook

## Steps
1. `./redmine/backup-restore.sh prod`
2. Enter backup date
3. Smoke tests: node, service, HTTP 200, DB, files mount
4. Report: `/backup/reports/restore-test-redmine-*.md`
