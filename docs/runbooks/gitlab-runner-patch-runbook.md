# GitLab Runner Patch Runbook

## Prerequisites
- [ ] User in `runner-admins` group
- [ ] All runners online

## Steps
1. `./gitlab-runner/change-request.sh prod patch`
2. `./gitlab-runner/patch.sh prod` — per-node rolling: precheck -> backup (config.toml) -> restore-test -> pause runner -> stop -> update binary -> verify -> resume
3. Verify: service active, config.toml intact, runner registered on GitLab

## Rollback
- Restore config.toml + previous binary
