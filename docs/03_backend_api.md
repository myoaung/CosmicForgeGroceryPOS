# 3. Backend API & Supabase Services

## 3.1 PostgREST API Integration
Because the architecture relies on Supabase, there is no traditional middleware REST API. Instead, the Flutter client communicates directly with PostgreSQL via the PostgREST auto-generated API.

- **Data Models**: Dart objects seamlessly map to Postgres tables (`products`, `inventory`, `orders`, `transactions`).
- **Security**: Direct API access is secured entirely via Postgres Row Level Security (RLS) policies utilizing JWT claims.

## 3.2 Custom Remote Procedure Calls (RPCs)
Business logic that requires elevated privileges or complex transactions is encapsulated in PostgreSQL Functions (RPCs):

- **`throttle_pin_login(p_email, p_device_id)`**: Handles rate-limiting for PIN logins to prevent brute-force attacks. Returns lockout statuses (`lockout_1m`, `lockout_5m`).
- **Audit Triggers**: Database triggers automatically append to `audit_logs` and maintain `updated_at` timestamps.

## 3.3 Supabase Storage
- **Bucket**: `product-images`
- **Access**: Private bucket. Read/Write access is enforced via Storage Policies that parse the `tenant_id` from the file path/metadata and compare it against the user's JWT.

## 3.4 Future Evolution: Edge Functions
Currently, the system relies heavily on thick-client logic. Future roadmaps (`Operation Oracle`) plan to introduce Supabase Edge Functions (Deno/TypeScript) for:
- Heavy analytical aggregations.
- Predictive inventory forecasting.
- Push notification dispatches.
