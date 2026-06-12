# Vault Patch Runbook

## Prerequisites
- [ ] User in `vault-admins` group
- [ ] Backup Exec restore job configured for staging
- [ ] SD+ change request created (risk: High)
- [ ] Unseal keys available (stored offline)

## Steps
1. `./vault/change-request.sh prod patch`
2. `./vault/patch.sh prod` — rolling update: precheck -> backup (raft snapshot + config) -> restore-test -> step-down node -> stop -> deploy binary -> verify -> re-enable LB
3. Verify: Vault health API, initialized/sealed status, service active

## Rollback
- Restore raft snapshot + previous binary
