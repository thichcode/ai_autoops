# GitLab Restore Runbook (Multi-Node)

## Steps

1. **Stop services on ALL app nodes**
   ```bash
   ssh gitlab-app01 'gitlab-ctl stop unicorn && gitlab-ctl stop workhorse && gitlab-ctl stop sidekiq'
   ssh gitlab-app02 'gitlab-ctl stop unicorn && gitlab-ctl stop workhorse && gitlab-ctl stop sidekiq'
   ```

2. **Restore PostgreSQL database**
   ```bash
   ssh gitlab-db01 'gunzip -c /backup/gitlab/db/gitlab-prod-20260611.sql.gz | psql -U gitlab gitlabhq_production'
   ```

3. **Restore NFS data** (from NFS backup)
   ```bash
   # Restore repos, uploads, builds, artifacts from NFS snapshot
   ```

4. **Restart services**
   ```bash
   ./gitlab/pipeline.sh start prod
   ./gitlab/health-check.sh prod
   ```
