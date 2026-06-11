# AI Ops — ISO 20000/27001 Operations Scripts

Production-ready scripts for backup-restore, patch-management, change-management, and security-compliance.

## Systems

| System | Tech Stack | Nodes |
|--------|-----------|-------|
| Jira Software | Java, MySQL Galera 8.0, NFS, NGINX Plus | 2 app + 2 DB |
| GitLab | Ruby/Rails, Omnibus, PostgreSQL | 1 |
| Coverity | Synopsys | 1 |
| BlackDuck | Synopsys | 1 |

## Quick Start

```bash
cp .env.template .env   # Fill in secrets
./jira/patch.sh prod 10.5.0
```

## Structure

```
shared/lib/       -- Cross-cutting library (logging, audit, notification, API wrappers)
jira/             -- Jira module
gitlab/           -- GitLab module
coverity/         -- Coverity module
blackduck/        -- BlackDuck module
docs/             -- Runbooks, compliance mapping
```

## Standards

- ISO 20000-1:2018 -- Change management, service management
- ISO 27001:2022 -- Access control, backup, logging, vulnerability management
