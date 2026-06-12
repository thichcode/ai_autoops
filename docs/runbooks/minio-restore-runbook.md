# MinIO Restore Runbook

## Steps
1. `./minio/backup-restore.sh prod` — enter backup date
2. Smoke tests (4): reachable, service, S3 API live, data integrity
3. Report: `/backup/reports/restore-test-minio-*.md`
