# ISO 20000-1:2018 — IT Service Management Mapping

## Clause Mapping

| ISO 20000 Clause | Requirement | Implementation |
|-----------------|-------------|----------------|
| 8.2 | Change Management | `pipeline.sh` implements Plan -> Approve -> Implement -> Verify -> Close lifecycle |
| 8.2.1 | Change requests documented | `change-request.sh` creates/updates CR in ManageEngine SD+ |
| 8.2.2 | Risk assessment | Pipeline precheck stage includes risk evaluation |
| 8.2.3 | Change approval | ManageEngine SD+ approval workflow (external) |
| 8.2.4 | Change implementation | Automated pipeline with rollback on failure |
| 8.2.5 | Post-implementation review | Verify stage + audit log + notification |
| 9.2 | Incident management | Failure notification to ops + security teams |
| 9.3 | Problem management | Audit trail for root cause analysis |
| 10.1 | Configuration management | Config files per environment (dev/staging/prod) |

## Change Record Fields (SD+)

Every change request includes:
- Title, description, category
- Priority, risk level
- Rollback plan
- Implementation plan
- Status tracking: Draft -> Approved -> In Progress -> Implemented -> Verified -> Closed
