# Vault Restore Runbook

## Steps
1. `./vault/backup-restore.sh prod` — enter backup date
2. Smoke tests (3): reachable, Vault API, service active
3. Report: `/backup/reports/restore-test-vault-*.md`
