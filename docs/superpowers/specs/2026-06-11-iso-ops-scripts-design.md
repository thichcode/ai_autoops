# ISO 20000/27001 Operations Scripts — Design Document

## Overview

Production-ready scripts for IT operations management following ISO 20000 (IT Service Management) and ISO 27001 (Information Security) standards. Covers 4 system modules: Jira, GitLab, Coverity, BlackDuck — each with backup-restore, patch-management, change-management, and security-compliance capabilities.

## Architecture

Hybrid monorepo: shared cross-cutting library (`shared/lib/`) + independent per-system pipeline modules.

**Languages:** PowerShell for Windows tasks (Backup Exec, Windows Event, ManageEngine API), Bash for Linux tasks (Jira app/DB, GitLab, etc.).

## Directory Structure

```
ai_ops/
├── shared/
│   ├── lib/
│   │   ├── log.sh / log.ps1              # Structured JSON logging, log levels, rotation
│   │   ├── audit.sh / audit.ps1          # Audit trail (who, what, when, result) → file + Syslog/Event
│   │   ├── notify.sh / notify.ps1        # Email + Slack + Webhook notification
│   │   ├── servicedesk-api.ps1           # ManageEngine SD+ REST API (create/get/update change request)
│   │   ├── backup-exec-api.ps1           # Backup Exec BEMCLI wrapper (trigger backup, verify job, restore)
│   │   ├── rollback.sh / rollback.ps1    # Generic rollback: snapshot restore, db restore, symlink swap
│   │   ├── secrets.ps1                   # Read .env / vault, no hardcoded credentials
│   │   └── utils.sh / utils.ps1          # Retry, timeout, checksum, SSH wrapper, RBAC check
│   ├── config/
│   │   └── global.cfg                    # Global defaults: log paths, notification recipients, SD+ URL
│   └── templates/
│       ├── precheck.sh / precheck.ps1    # Reusable stage templates
│       ├── backup.sh / backup.ps1
│       ├── drain.sh / drain.ps1
│       ├── deploy.sh / deploy.ps1
│       ├── verify.sh / verify.ps1
│       └── rollback.sh / rollback.ps1
│
├── jira/                                  # Jira Software v10.x Data Center
│   ├── pipeline.sh                        # Pipeline template (precheck→backup→drain→deploy→verify→rollback|commit→audit)
│   ├── stages/                            # Jira-specific stage overrides
│   │   ├── precheck.sh                    # Check both app nodes + Galera sync + NFS + NGINX upstream
│   │   ├── backup.sh                      # Trigger BE job, verify, db dump via mysqldump
│   │   ├── drain.sh                       # Remove node from NGINX Plus upstream, wait for active requests to drain
│   │   ├── deploy.sh                      # Stop node, extract jira tar.gz, run upgrade, liquibase migration
│   │   ├── verify.sh                      # Health check API, DB replication, NGINX upstream healthy
│   │   └── rollback.sh                    # Restore from BE backup, swap to previous install dir
│   ├── config/
│   │   ├── shared.cfg                     # Common: install path, user, service name
│   │   ├── prod.cfg                       # Production: node IPs, Galera hosts, NGINX upstream name, NFS mount
│   │   └── staging.cfg
│   ├── patch.sh                           # Entrypoint: orchestrate patch across both nodes (rolling)
│   ├── backup-restore.sh                  # Entrypoint: manual backup / restore from BE
│   ├── change-request.sh                  # Entrypoint: ManageEngine SD+ change request CRUD
│   └── health-check.sh                    # Entrypoint: full cluster health report
│
├── gitlab/                                # GitLab (self-managed, Omnibus)
│   ├── pipeline.sh
│   ├── stages/
│   ├── config/
│   ├── patch.sh
│   ├── backup-restore.sh
│   ├── change-request.sh
│   └── health-check.sh
│
├── coverity/                              # Coverity (Synopsys) — structure similar
│   └── ...
├── blackduck/                             # BlackDuck (Synopsys) — structure similar
│   └── ...
│
├── docs/
│   ├── runbooks/
│   │   ├── jira-patch-runbook.md
│   │   ├── jira-restore-runbook.md
│   │   ├── gitlab-patch-runbook.md
│   │   └── gitlab-restore-runbook.md
│   └── compliance/
│       ├── iso-20000-mapping.md
│       └── iso-27001-mapping.md
│
├── .env.template                          # Template for secrets (gitignored)
├── .gitignore
└── README.md
```

## Pipeline Stages

Every `pipeline.sh` implements a standardized sequence:

| # | Stage | Description | ISO Ref |
|---|-------|-------------|---------|
| 1 | PRE-CHECK | Disk space, node reachable, DB sync, backup age valid, RBAC check | 27001 A.12.5 |
| 2 | BACKUP | Trigger BE backup, verify job completed, checksum manifest | 27001 A.12.3 |
| 3 | DRAIN | Remove node from LB, wait for draining connections | 20000 9.2 |
| 4 | MAINT-MODE | Set maintenance page, stop service | 20000 9.2 |
| 5 | DEPLOY | Apply patch/update, run DB schema migration (once) | 20000 9.2 |
| 6 | VERIFY | Health check, smoke test, DB replication verification | 20000 9.3 |
| 7 | COMMIT / ROLLBACK | Re-enable node (OK) OR restore from backup (FAIL) | 20000 9.4 |

**Rolling update for multi-node:** Nodes are patched one at a time. DB migration runs only from the first node.

## Configuration Hierarchy

```
shared/config/global.cfg       # Read by all systems
system/config/shared.cfg       # Read by system, all environments
system/config/prod.cfg         # Environment-specific (override)
.env                           # Secrets (gitignored)
```

Secrets resolution order: `.env` > `prod.cfg` > `shared.cfg` > `global.cfg` (first wins).

## Change Management (ManageEngine ServiceDesk Plus)

The `change-request.sh` script wraps the SD+ REST API:

- `change-request.sh create --title "Jira v10.x patch prod" --risk medium --priority high`
- `change-request.sh update --id CR123 --status "In Progress"`
- `change-request.sh add-note --id CR123 --note "Pre-check passed, starting backup..."`

Pipeline auto-updates CR status through its lifecycle. Audit log is attached to CR on close.

## Security Controls (ISO 27001)

| Control | Implementation |
|---------|---------------|
| A.9.1 Access Control | RBAC check: verify user in `jira-admins` / `gitlab-ops` group |
| A.9.4 Credential Management | `.env` gitignored; `secrets.ps1` decrypts from vault; no hardcoded creds |
| A.12.3 Backup | Backup must complete successfully before deploy; verified by checksum |
| A.12.4 Logging & Monitoring | JSON audit to file + Syslog (Linux) / Windows Event (Windows); includes user, timestamp, action, result |
| A.12.5 Control of Operational Software | Script SHA-256 verification before execution (`.sha256` sidecar files) |
| A.12.6 Technical Vulnerability Management | Patch pipeline includes vulnerability scan trigger (openVAS/nessus placeholder) |
| A.16 Incident Management | Auto-notify security team on failure; link CR to incident if rollback fails |

## Notification Channels

- **Email** (SMTP) — change request status updates, failure alerts
- **Slack Webhook** — real-time ops channel notifications
- **ManageEngine SD+** — change request notes & status sync

## Error Handling

- Every stage has `trap` for unexpected errors → auto-rollback on failure
- Rollback is mandatory before re-try
- Notification sent to ops team + Security team on failure
- Audit log records both success and failure with full context

## Non-Functional Requirements

- **Idempotency**: Re-running a completed pipeline stage is safe; every operation checks current state before action
- **Auditability**: Every execution produces a complete JSON audit record
- **Minimal downtime**: Rolling update for Jira DC — zero downtime target
