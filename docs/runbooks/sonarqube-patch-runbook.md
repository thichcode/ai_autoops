# SonarQube Patch Runbook

## Prerequisites
- [ ] User in `sonar-admins` group
- [ ] Backup Exec restore job configured for staging
- [ ] ManageEngine SD+ change request created

## Steps

1. **Create Change Request** `./sonarqube/change-request.sh prod patch`

2. **Run Patch Pipeline** `./sonarqube/patch.sh prod`
   Pipeline: precheck -> backup (DB + conf) -> restore-test -> drain LB -> stop -> deploy -> verify -> re-enable LB

3. **Verify**
   - SonarQube UI accessible
   - Analyses can be triggered
   - DB connection OK

## Rollback
- Pipeline auto-rolls back
- Restore DB dump + previous install
