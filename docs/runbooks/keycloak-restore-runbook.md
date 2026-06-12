# Keycloak Restore Runbook

## Steps
1. `./keycloak/backup-restore.sh prod` — enter backup date
2. Smoke tests (4): node reachable, service, OIDC config, DB reachable
3. Report: `/backup/reports/restore-test-kc-*.md`
