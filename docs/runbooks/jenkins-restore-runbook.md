# Jenkins Restore Runbook

## Steps
1. `./jenkins/backup-restore.sh prod`
2. Enter backup date when prompted
3. Smoke tests: node reachable, service active, HTTP 200, JENKINS_HOME integrity
4. Report: `/backup/reports/restore-test-jenkins-*.md`
