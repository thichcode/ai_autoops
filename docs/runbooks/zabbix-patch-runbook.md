# Zabbix Patch Runbook

## Prerequisites
- [ ] User in `zabbix-admins` group
- [ ] Backup Exec restore job configured for staging
- [ ] Change request created
- [ ] All proxies online

## Steps

1. **Create Change Request** `./zabbix/change-request.sh prod patch`

2. **Run Patch Pipeline** `./zabbix/patch.sh prod`
   Pipeline: precheck -> backup (DB + conf) -> restore-test -> drain proxies -> stop services -> deploy (yum update) -> verify -> re-enable proxies

3. **Verify**
   - Zabbix web UI accessible
   - Server process active
   - All proxies connected
   - New data being collected

## Rollback
- Pipeline auto-rolls back
- Restore DB + yum history undo
