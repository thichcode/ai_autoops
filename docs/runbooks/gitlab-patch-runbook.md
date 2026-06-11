# GitLab Patch Runbook (Multi-Node)

## Topology

| Component | Nodes | Role |
|-----------|-------|------|
| App | gitlab-app01, gitlab-app02 | Rails, Sidekiq, Workhorse |
| Database | gitlab-db01 | PostgreSQL 14+ |
| Redis | gitlab-redis01 | Redis 7.x (caching) |
| NFS | gitlab-nfs01, gitlab-nfs02 | Shared storage (repos, uploads, artifacts) |
| Load Balancer | NGINX Plus | Distributes traffic across app nodes |

## Prerequisites
- [ ] User in `gitlab-ops` group
- [ ] SSH key access to all nodes
- [ ] PostgreSQL pg_dump permissions
- [ ] NGINX Plus API accessible from controller host
- [ ] ManageEngine SD+ change request created

## Steps

1. **Create Change Request**
   ```bash
   ./gitlab/change-request.sh create \
     "GitLab upgrade to 16.11.0 (prod)" \
     "Regular version upgrade - multi-node rolling" \
     "High"
   ```

2. **Run Patch Pipeline** (rolling update)
   ```bash
   ./gitlab/patch.sh prod 16.11.0
   ```
   Pipeline: precheck -> backup -> restore-test (BE -> staging + smoke tests) -> drain node1 -> deploy -> verify -> drain node2 -> deploy -> verify
   Restore-test generates formal report at `/backup/reports/restore-test-gitlab-*.md`.

3. **Post-Verify**
   ```bash
   ./gitlab/health-check.sh prod
   ```

4. **Close Change Request**
   ```bash
   ./gitlab/change-request.sh update CR-124 "Closed"
   ```

## Rollback
- Pipeline auto-rolls back if verify stage fails on any node
- Manual rollback: downgrade package via apt on each node + restore DB from backup
