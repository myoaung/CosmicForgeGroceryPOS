# 🛒 Cosmic Forge POS

![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?style=flat-square&logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.2+-0175C2?style=flat-square&logo=dart)
![Supabase](https://img.shields.io/badge/Supabase-DB_&_Auth-3ECF8E?style=flat-square&logo=supabase)
![Drift](https://img.shields.io/badge/Drift-Offline_First-4285F4?style=flat-square&logo=sqlite)

Cosmic Forge POS is an enterprise-grade, offline-first, multi-tenant point of sale platform designed for retailers in Myanmar. It combines a Flutter client, encrypted local storage, and Supabase-backed cloud services to keep stores selling even when the network is unreliable.

## ✨ Key Features & Architecture

- **📶 Offline-First First:** Transactions, products, and carts are always available locally using **Drift (SQLite)** and `SQLCipher` for at-rest encryption. The `SyncService` handles background queueing, exponential backoffs, and Last-Write-Wins (LWW) conflict resolution with Supabase.
- **🛡️ Enterprise Security & Multi-Tenancy:**
  - **Row-Level Security (RLS):** Strict tenant isolation at the database level using `tenant_id` claims locked inside Supabase JWTs.
  - **Hardware Binding & Geofencing:** Device sessions are bound to specific `authorized_bssid` Wi-Fi networks and strictly geofenced within a 100m radius of the store's GPS coordinates.
- **🏬 Multi-Store Context:** A single tenant can manage multiple branches. The `StoreService` (powered by Riverpod) handles dynamic `tax_rate` loading and store-specific inventory views.
- **🇲🇲 Myanmar Localization:** Bilingual support out of the box using `intl`. Enforces standard **Unicode (Pyidaungsu)** and robust Myanmar Kyat (MMK) rounding rules (nearest 5 or 10 Kyat).

## 🗂️ Repository Layout

```text
lib/
 ├─ core/             # Auth, security, repositories, services, database
 ├─ data/             # Data transfer objects & schema helpers
 ├─ domain/           # Pure business models & use cases
 ├─ features/         # UI modules (auth, pos, products, admin, history...)
 ├─ infrastructure/   # Platform adaptors & external integrations
 └─ services/         # Cross-cutting application services
infra/
 └─ supabase/
     └─ migrations/   # SQL migrations & RLS policies
```

## 🛠️ Prerequisites

- Flutter SDK 3.24+ (using fvm or global install)
- Dart 3.2+
- Supabase project (PostgreSQL 15) with REST + Auth enabled
- Docker Desktop (for local Postgres/Redis via `docker-compose.yml`)
- Supabase CLI (optional but highly recommended for local development)
- For Android release: valid keystore and `ANDROID_KEY_*` properties

## 🚀 Getting Started

1. **Install Dependencies**
   ```powershell
   flutter pub get
   ```

2. **Configure Environment**
   ```powershell
   cp .env.example .env
   ```
   Provide your `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and other required secrets. For CI/CD, these are injected via GitHub Secrets or `scripts/generate_secrets.ps1`.

3. **Run Local Infrastructure (Optional)**
   Spin up local Supabase instances and apply database migrations:
   ```powershell
   docker-compose up -d postgres redis
   supabase migration up
   ```

4. **Launch the App**
   ```powershell
   flutter run
   ```
   *Tip: You can pass Supabase credentials directly via build args if you skip `.env`:*
   ```powershell
   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
   ```

## 📜 Day-to-Day Commands

| Task | Command |
|------|---------|
| **Format & Analyze** | `flutter analyze` |
| **Run Unit/Widget Tests** | `flutter test` |
| **Run POS Integration Tests**| `flutter test test/features/pos` |
| **Run Chaos/Sync Tests** | `flutter test test/chaos` |
| **Build Android Release** | `flutter build apk --release --dart-define=...` |

## 🔒 Security & Secrets Management

- **Zero Hard-coded Secrets:** All sensitive configurations flow through `.env`, CI runners, or PowerShell scripts.
- **Session Context:** JWT claims (`tenant_id`, `store_id`, `role`, `device_id`) are parsed intrinsically via `core/auth/session_context.dart`.
- **Audit Logging:** The `AuditLogService` ensures immutable trails for sensitive actions (e.g., store switching, tax overrides, sync failures).

## 📡 Sync Engine Snapshot

The sync engine uses the `sync_queues` table to track offline modifications:
- **States:** `pending`, `processing`, `success`, `failed`, `dead_letter`.
- **Retry Policy:** Exponential backoff (base 5s, doubling each attempt up to 6 limits).
- **Service Hub:** `SyncService` coordinates workers every 60s and provides manual overrides like `manualSyncNow()`.

## 📈 Observability (Planned)

The architecture includes hooks for deep observability through `ObservabilityService`:
- **Sentry Integration:** Capturing unhandled async Drift exceptions and sync queue failures.
- **Prometheus Exporters:** Custom metrics for queue length, dead letters, and API latency (see `docs/observability.md`).

## ❓ Troubleshooting

| Symptom | Fix |
| ------- | --- |
| `Supabase.initialize must be called` | Ensure `.env` is loaded properly or supply it via `--dart-define`. |
| Drift SQLCipher Errors | Make sure `sqlcipher_flutter_libs` is resolving correctly for your native platform. |
| Sync Queue stuck on `failed` | Tap **Manual Sync** on the Admin Dashboard or check `sync_queues` for `dead_letter` status. |
| Long Launch Pauses | The `BackupService` runs a `VACUUM INTO` check on startup. Check logs to see if a massive DB is hanging. |

## 🤝 Contributing

1. Create a feature branch from `main`.
2. Implement your changes alongside relevant unit/integration tests.
3. Validate strict linting with `flutter analyze`.
4. Submit a Pull Request! GitHub Actions will take over and enforce CI checks.

---
*Together we can keep Myanmar retailers selling, even when the internet goes dark.*
