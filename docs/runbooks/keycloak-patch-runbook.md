# Keycloak Patch Runbook

## Prerequisites
- [ ] User in `keycloak-admins` group
- [ ] Backup Exec restore job configured for staging
- [ ] SD+ change request created (risk: High)

## Steps
1. `./keycloak/change-request.sh prod patch`
2. `./keycloak/patch.sh prod` — rolling update per node: precheck -> backup (DB + realm exports + themes) -> restore-test -> drain node -> stop -> deploy -> verify -> re-enable
3. Verify: OIDC issuer, service active, realm accessible

## Rollback
- Restore DB dump + previous install + realm import
