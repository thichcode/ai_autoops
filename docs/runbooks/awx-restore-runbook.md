# AWX Restore Runbook

## Steps
1. `./awx/backup-restore.sh prod` — enter backup date
2. Smoke tests (4): node reachable, container/service, HTTPS, DB reachable
3. Report: `/backup/reports/restore-test-awx-*.md`
