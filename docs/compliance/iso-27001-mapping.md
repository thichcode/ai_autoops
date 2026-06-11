# ISO 27001:2022 — Information Security Mapping

## Annex A Control Mapping

| ISO 27001 Control | Requirement | Implementation |
|-------------------|-------------|----------------|
| A.8.1 | Asset management | `health-check.sh` reports system status |
| A.8.9 | Configuration management | Environment configs under version control |
| A.8.10 | Information deletion | Backup retention policies in config |
| A.8.11 | Data masking | Secrets in .env (gitignored), not in scripts |
| A.8.12 | Data leakage prevention | Audit log monitors all operational changes |
| A.8.24 | Use of cryptography | Checksum verification (SHA-256) for scripts |
| A.8.25 | Secure development | Script signing via .sha256 sidecar files |
| A.8.29 | Security testing | Health-check scripts for post-deploy verification |
| A.8.32 | Change management | Pipeline with rollback (aligned with ISO 20000) |
| A.8.33 | Backup | Backup stage before all deploy operations |
| A.8.34 | Backup verification | Checksum verification of backup files |
| A.8.35 | Logging | Structured JSON audit to file + Syslog/Event |
| A.8.36 | Log protection | Audit log in restricted directory |
| A.8.37 | Clock synchronization | Timestamps in UTC ISO 8601 format |
| A.8.39 | Privileged access | RBAC check before any operation |
| A.8.40 | Vulnerability management | Patch pipeline (placeholder for scan trigger) |

## Audit Record Format

Every operation generates:
```json
{
  "timestamp": "2026-06-11T10:00:00Z",
  "user": "ops_admin",
  "host": "jira-app01",
  "pid": 12345,
  "action": "PIPELINE_START",
  "status": "STARTED",
  "details": "Jira patch pipeline on prod"
}
```
