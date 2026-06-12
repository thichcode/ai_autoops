# Harbor Restore Runbook

## Steps
1. `./harbor/backup-restore.sh prod` — enter backup date
2. Smoke tests (4): node reachable, harbor-core container, API ping, HTTPS 200
3. Report: `/backup/reports/restore-test-harbor-*.md`
