# Jenkins Patch Runbook

## Prerequisites
- [ ] User in `jenkins-admins` group
- [ ] Backup Exec restore job configured for staging target
- [ ] ManageEngine SD+ change request created
- [ ] All agents online and reachable

## Steps

1. **Create Change Request** `./jenkins/change-request.sh prod patch`

2. **Run Patch Pipeline** `./jenkins/patch.sh prod`
   Pipeline: precheck -> backup (JENKINS_HOME + plugins) -> restore-test -> drain agents -> stop Jenkins -> deploy war -> verify -> reconnect agents

3. **Verify**
   - Jenkins UI accessible via LB URL
   - All agents connected and online
   - Critical jobs can be executed

## Rollback
- Pipeline auto-rolls back on failure
- Manual: restore war backup + JENKINS_HOME
