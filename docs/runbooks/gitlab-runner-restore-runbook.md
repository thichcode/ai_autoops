# GitLab Runner Restore Runbook

## Steps
1. `./gitlab-runner/backup-restore.sh prod` — enter backup date
2. Smoke tests (3): node reachable, service active, config.toml exists
3. Report: `/backup/reports/restore-test-runner-*.md`
