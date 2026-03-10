# Cosmic Forge POS Security Incident Response
*Last updated: 2026-03-08 UTC*

## Scope
This runbook covers enterprise POS security incidents:
- data breach
- device theft
- database compromise
- sync failure
- credential leak

## Severity Levels
- `SEV-1`: confirmed data exposure, active compromise, payment risk.
- `SEV-2`: high-risk security control bypass with no confirmed exfiltration.
- `SEV-3`: contained issue with low immediate business impact.

## Response Team
- Incident Commander: Engineering Lead
- Security Owner: Platform Security
- Ops Owner: SRE / DevOps
- Product Owner: POS Program Manager

## Immediate Actions (All Incidents)
1. Open incident channel and assign Incident Commander.
2. Capture timeline start (`UTC timestamp`) and impacted tenant/store.
3. Preserve evidence (logs, device state, CI run IDs, DB snapshots).
4. Contain blast radius before remediation.

## Data Breach Procedure
1. Disable affected API keys and rotate JWT secret.
2. Revoke active sessions for impacted tenant(s).
3. Lock affected accounts and force password reset.
4. Export audit logs for legal/compliance handling.
5. Validate RLS policies and cross-tenant access guards before recovery.

## Device Theft Procedure
1. Mark device `status='disabled'` in `devices` table.
2. Revoke sessions linked to `device_id`.
3. Block device from POS access (`DeviceGuard` will reject non-active devices).
4. Rotate store credentials and perform store network check.
5. Re-provision replacement device with a new `device_id`.

## Database Compromise Procedure
1. Isolate compromised DB endpoint and switch to backup/failover node.
2. Rotate DB credentials and Supabase service role key.
3. Restore from last known good backup and verify integrity checks.
4. Reconcile transaction parity against local sync queues.
5. Re-enable write traffic only after validation and approval.

## Sync Failure Procedure
1. Detect queue backlog (`sync_queue` pending/failed/dead_letter counts).
2. Validate network and Supabase health.
3. Trigger manual sync and inspect dead-letter payloads.
4. Escalate if backlog exceeds SLA window.
5. Document root cause and permanent fix.

## Credential Leak Procedure
1. Rotate leaked credentials immediately:
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE`
   - `JWT_SECRET`
   - any exposed CI/deploy token
2. Invalidate current sessions.
3. Re-run CI security scan and secret detection.
4. Confirm no hardcoded secrets remain in git history.

## Emergency Control Checklist
- Disable affected device
- Revoke user sessions
- Rotate secrets
- Restore backup
- Validate RLS and tenant isolation
- Confirm audit logging operational

## Pending Hardening Actions
- Pin login throttling + hashing plan documented in `infra/supabase/migrations/pending_rpc_hardening.sql`.
- Security audit summary (roles, telemetry, secrets) lives in `docs/security.md`; sync this page with that audit when executing the next incident response review.
- Contributor guide checklist for these infra/QA tasks is in `docs/contributor-guide.md`.

## Post-Incident Review
1. Produce RCA within 72 hours.
2. Add detection/prevention controls to CI and runtime monitoring.
3. Update this runbook and engineering tests.
4. Track remediation items to closure.
