# SonarQube Restore Runbook

## Steps
1. `./sonarqube/backup-restore.sh prod`
2. Enter backup date
3. Smoke tests: node, service, HTTP 200, DB reachable
4. Report: `/backup/reports/restore-test-sonar-*.md`
