# API Endpoints

## Supabase Auth

- `POST https://<SUPABASE_URL>/auth/v1/token`: exchange email/password (or refresh token) for JWTs. Clients must provide `grant_type=password` plus `email`/`password` or `grant_type=refresh_token`. Responses include `access_token`, `refresh_token`, and `expires_in`. The app stores these via `SecureStorageService` (`lib/core/security/secure_storage_service.dart:55`).
- `POST https://<SUPABASE_URL>/auth/v1/otp` and `POST /auth/v1/otp/send`: optional OTP/pin flows used by `AuthService` for “pin mode” login (`lib/features/auth/auth_service.dart:1-140`), but Supabase manages the backend OTP lifecycle.

## REST Tables (Base path `https://<SUPABASE_URL>/rest/v1/{table}`)

All table access requires an authenticated JWT with the correct `tenant_id`, `store_id`, and `role` claims because RLS is enabled on every table (`infra/supabase/migrations/20260308_enterprise_security_controls.sql:261-316`). Tenant-level super admins bypass most restrictions via `is_admin_role()`.

### `tenants`
- Methods: `GET`, `POST`, `PATCH`, `DELETE` (authenticated) scoped by `tenant_id`.
- Purpose: record tenant metadata (`business_name`, `plan_type`, `status`).
- Required fields: `tenant_id`, `business_name`. `POST` must include `tenant_id` UUID; Supabase can emit via `gen_random_uuid()`.

### `stores`
- Methods: `GET`, `POST`, `PATCH`, `DELETE`.
- Additional fields: `timezone`, `currency_code`, `tax_rate`, `bssid`, `ip_range`.
- All CRUD operations honor tenant+store RLS; `setActiveStore` ensures the client only requests matching `tenant_id`/`store_id` (`lib/core/services/store_service.dart:16-205`).

### `users`
- Methods: `GET`, `PATCH`.
- Fields: `auth_user_id`, `role`, `is_active`. Clients read via Supabase client to check roles and logout flows (`lib/features/auth/auth_provider.dart:1-210`). Supabase manages creation via `supabase.auth`.

### `devices`
- Methods: `GET`, `POST`, `PATCH`.
- Clients register and validate device meta (`DeviceRegistryService` / `DeviceGuard`) to enforce geofencing, BSSID, and IP restrictions (`lib/core/security/device_registry_service.dart:6-59`, `lib/core/security/device_guard.dart:6-47`).
- Required `tenant_id`, `store_id`, `device_id`, optional `bssid`, `ip_range`. RLS ensures only the owning tenant can query by `device_id`.

### `products`
- Methods: `GET`, `POST`, `PATCH`, `DELETE`.
- Fields mirror `LocalDatabase.products` plus `sku`, `version`, `updated_at`, `created_at` (`infra/supabase/migrations/20260308_enterprise_multitenant_rls.sql:1-150`).
- SyncService pushes product payloads via `_gateway.upsertProduct`.
- GET queries filter by `tenant_id`/`store_id`; meta stored locally helps drive `productsProvider` (`lib/features/products/providers/product_provider.dart:9-37`).

### `inventory`
- Methods: `GET`, `PATCH`.
- Tracks stock per tenant/store. Checkout use case updates `stock` via `syncQueues` and the `inventory` endpoint (`lib/core/usecases/checkout_use_case.dart:9-129`).

### `orders`, `order_items`, `payments`
- These tables capture finalized sales (headers/items) and payments. Checkout pushes to `syncQueues` which eventually call the REST endpoints through Supabase (`SyncQueueWorker._applySyncOperation`). Include `tenant_id`, `store_id`, `transaction_id`, `product_id`, and monetary fields (`infra/supabase/migrations/20260308_enterprise_security_controls.sql:276-294`).

### `transactions` and `transaction_items`
- Local `transactions` table replicates to the cloud via SyncService’s `syncPendingTransactions()` (`lib/core/services/sync_service.dart:107-292`).
- Each item requires `tenant_id`/`store_id` fields because Supabase RLS policy `transaction_items_tenant_store_isolation` is enforced (`infra/supabase/migrations/20260308_enterprise_security_controls.sql:276-294`). Include `id`, `subtotal`, `tax_amount`, `total_amount`, `timestamp`, `product_id`, `quantity`, `unit_price`, and `tax_amount`.

### `reports`
- Methods: `GET`, `POST`, `PATCH`.
- Payload is JSON, e.g. generated analytics exported from dashboards. Every row requires `tenant_id`/`store_id`.

### `audit_logs`
- Methods: `POST` (and optional `GET` for admin).
- Clients log critical actions (`StoreService.logAudit`, `AuditLogService`) with `event_type`, `event_data`, and the resolved tenant/store/user IDs (`lib/core/services/audit_log_service.dart:3-33`).

## Storage: `product-images` bucket

- Path: `https://<SUPABASE_URL>/storage/v1/object/public/product-images/{tenant_id}/{product_id}{ext}` (default private, served via signed URLs).
- Upload flow: clients call `SupabaseStorageService.uploadProductImage` -> `storage.from('product-images').uploadBinary` -> `createSignedUrl` for retrieval (`lib/core/services/supabase_storage_service.dart:7-66`).
- RLS-like policies ensure only the owning tenant can read/write (`infra/supabase/migrations/20260308_enterprise_security_controls.sql:318-361`).
- Signed URLs expire after 7 days by default; refresh when necessary before showing product images.

## Usage notes

- Always include `Authorization: Bearer <access_token>` header and `apikey: <anon key>` when hitting `/rest/v1` endpoints.
- Use `Prefer: return=representation` for inserts when the UI needs the created row (e.g., to seed local Drift objects).
- Follow `set_updated_at` trigger to keep `updated_at` fresh (`infra/supabase/migrations/20260308_enterprise_multitenant_rls.sql:1-150`).
- Supabase will reject writes that don’t match `tenant_id`/`store_id` claims; handle `403` gracefully by logging via `ObservabilityService`.
