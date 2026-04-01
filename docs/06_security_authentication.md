# 6. Security Controls & Authentication

## 6.1 Authentication Flows
- **Cloud Login**: The initial login generates a JWT via `Supabase Auth`. This JWT encodes custom claims storing the user's explicit multi-tenant roles (`tenant_id`, `role`, `auth_user_id`).
- **PIN Login Lockout**: Cashiers generally switch profiles using a local generated 6-digit PIN. To mitigate brute-force guessing against the edge device:
  - **3-5-15 Strategy**: The local `AuthService` tracks failed attempts. After 3 failures: 1 min lockout. 5 failures: 5 min. 10+ failures: Complete terminal lockout requiring remote manager unblock. 

## 6.2 Data Security (RLS)
PostgreSQL handles 100% of data governance. Row Level Security policies (`20260308_enterprise_security_controls.sql`) mandate that EVERY access layer validates the JWT custom claims against the table rows.
- **Tenant Isolation**: `tenant_id = public.jwt_claim('tenant_id')`
- **Audit Logs**: Immutable. App-client tokens are strictly locked to `FOR INSERT` and `FOR SELECT` only. Updates/Deletes on audit histories are physically impossible unless connecting directly to the infrastructure as a superuser.

## 6.3 Hardware & Physical Security
- **Secure Storage**: Drift SQLite databases are stored encrypted via generated AES-256 keys cached inside the Android Keystore & iOS Secure Enclave using `flutter_secure_storage`.
- **Geofencing (`SecurityGuard`)**: The POS terminal will not transact logic if it detects it has been stolen or moved from the store premises. It enforces physical presence via:
  1. GPS Hardware Haversine bounds (< 100m from registered store coordinates).
  2. BSSID Router checks (Requires connectivity to the known store Wi-Fi network).
- **Device Identifiers**: JWT tokens are supplemented by MAC address/Android IDs. If an invalid device attempts to intercept a JWT token, the backend edge logic actively rejects the payload.
