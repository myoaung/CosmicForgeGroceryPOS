# Pending Repo-Local Tasks

1. Flesh out the `pin_login` migration in Supabase:
   - enforce throttling (per-email/device rate limit) and hashed PIN verification,
   - log suspicious attempts,
   - ensure RBAC checks (role claims) guard the RPC.

2. Implement actual Sentry and Prometheus exporters referenced in `lib/core/services/observability_service.dart` and `docs/observability.md`.

3. Convert the placeholder tests under `test/core/services/` into runnable sandbox-integration tests that exercise RLS/RBAC and sync metadata propagation against a Supabase staging project.

4. Validate offline-first checkout → sync queue retries → conflict resolution flows manually or via automation to prove data consistency.

5. Regression test RBAC/RLS/admin UI flows (e.g., store switches, tax overrides, admin dashboards) with the Supabase policies in place before any release.
