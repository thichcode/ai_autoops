# MinIO Patch Runbook

## Prerequisites
- [ ] User in `minio-admins` group
- [ ] Backup Exec restore job configured for staging
- [ ] SD+ change request created
- [ ] mc client configured

## Steps
1. `./minio/change-request.sh prod patch`
2. `./minio/patch.sh prod` — rolling per node: precheck -> backup (mc mirror + config export) -> restore-test -> drain LB -> stop -> deploy binary -> verify -> re-enable
3. Verify: S3 API live, Console UI, service active, buckets accessible

## Rollback
- Restore previous binary + mc mirror reverse
