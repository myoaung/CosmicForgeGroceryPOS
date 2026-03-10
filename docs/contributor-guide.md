# Contributor Guide

## Onboarding Checklist
1. Run `flutter pub get` and `flutter test` locally to validate the core suite.
2. Confirm `.env` is populated per `.env.example` and `scripts/generate_secrets.ps1` works with your CI secrets.
3. Review `docs/security.md` and `docs/security_incident_response.md` for current security obligations before touching auth, RBAC, or SST integrations.

## Infra & QA Tasks (must be validated outside this repo)
- Harden `pin_login` RPC in Supabase (rate-limiting/hashing/logging) and commit the resulting migration (see `infra/supabase/migrations/pending_rpc_hardening.sql` for the stub). This is required before releasing a PIN-based login feature.
- Mirror every client-facing RBAC guard (`lib/features/auth/auth_provider.dart`, store service overrides) with Supabase RLS policies and test them inside your Supabase staging project.
- Wire Sentry & Prometheus integrations described in `docs/observability.md`; update `lib/core/services/observability_service.dart` placeholders with actual SDK imports and exporters.
- Execute integration suites that cover offline checkout → sync queue → conflict resolution flows and confirm Prometheus metrics expose queue length/retry counts.
- Add sandbox tests that attempt writes without tenant/store claims to prove RLS denies them; keep these tests (e.g., `test/core/services/...`) updated so they can be rerun in CI.

## Documentation Standards
- When updating architecture, security, or data-model docs, reference the code file paths (e.g., `lib/core/services/sync_service.dart:120-335`) and keep the markdown in `docs/`.
- Link new docs in `README.md` so they’re discoverable from the repo root.

## Release Notes
- Summarize fixes/risks from this guide alongside CI results in your release PR template so ops and security teams can sign off before shipping.
