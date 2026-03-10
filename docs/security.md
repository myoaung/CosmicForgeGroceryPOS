# Security Audit Summary

## Authentication
- Supabase handles the core auth flows (`auth_service.dart`, `auth_session_manager.dart`), but the app hardens them by enforcing TLS before any request and validating password/pin policies before calling `signInWithPassword` or `pin_login`.
- Sessions are persisted by `SecureStorageService` (SQLCipher key + FlutterSecureStorage) and refreshed via `AuthSessionManager` to minimize stale tokens.
- **Recommendation:** Document RPC safeguards (rate limiting, hashing) for `pin_login` and ensure the Supabase function validates `device_id`.

## RBAC
- `auth_provider.dart` exposes role-aware helpers (`canCheckoutProvider`, `isAdminSessionProvider`) that gate UI flows. 
- Sensitive actions such as tax overrides now call `_isAuthorizedForTaxOverride` to restrict to store managers, tenant admins, and super admins (`store_service.dart`).
- **Recommendation:** Mirror these guards in Supabase RLS policies so even API calls issued outside the client must respect the same roles.

## Row-Level Security (RLS)
- Enterprise migrations enable RLS on every core table and introduce policies for tenant/store isolation plus admin overrides (`infra/supabase/migrations/20260308_enterprise_security_controls.sql`, `20260308_enterprise_multitenant_rls.sql`).
- `SyncService` now includes `tenant_id`/`store_id` in every transaction item/product payload (`lib/core/services/sync_service.dart`), ensuring Supabase accepts them.
- **Recommendation:** Add integration tests (or sandbox checks) that attempt to write without store/tenant claims to surface regressions early.

## Secrets Management
- Secrets inject via GitHub Actions + `scripts/generate_secrets.ps1` before native builds (`.github/workflows/ci.yml`). `.env` is gitignored and `.env.example` documents the required keys.
- SQLCipher uses a key derived/storage in secure storage so the local DB is encrypted even if the file is stolen (`database_connection_native.dart`, `secure_storage_service.dart`).
- **Recommendation:** Extend `docs/ci_secrets_verification.md` with rotation evidence and ensure the service role key never ships with the client.

## Risks & Next Steps
1. **Pin login RPC** needs server-side throttling and logging to defend against brute force; see `infra/supabase/migrations/pending_rpc_hardening.sql` for the SQL scaffold to implement, and convert the placeholder SQL into executed DDL before shipping.
2. **Role enforcement** should be checked against Supabase policies (use `auth.jwt()->>'role'` selectors and match the helpers documented in `auth_provider.dart`); the placeholder RBAC integration test (`test/core/services/store_service_rbac_test.dart`) should validate negative/positive flows.
3. **Sync queue metadata** must be validated end-to-end; turn `test/core/services/sync_service_integration_test.dart` into a real integration that exercises tenant/store propagation before hitting Supabase.
4. **Observability wiring** requires actual Sentry + Prometheus integrators; `lib/core/services/observability_service.dart` now includes placeholders linked to `docs/observability.md`.
5. **Documentation**: Link this audit to the incident response runbook (`docs/security_incident_response.md`) and update the contributor checklist in `docs/contributor-guide.md` to reflect these outstanding infra/QA tasks.
