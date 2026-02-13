# REASONING.md - Architectural Decisions

## 1. Row-Level Security (RLS) & Tenant Isolation
**Decision**: Enforce strict RLS policies on all tables, keyed by `tenant_id`.
**Reasoning**:
- **Multi-Tenancy**: The application is designed to serve multiple grocery stores (tenants) from a single database instance. Data leakage between tenants is unacceptable.
- **Security-in-Depth**: Application-level filtering is insufficient. RLS provides a database-level guarantee that a tenant can only access their own data, even if the application logic has bugs.
- **Implementation**:
  - Every table (except system tables) MUST have a `tenant_id` column.
  - The `auth.jwt()` function in Postgres will be used to extract the `tenant_id` from the user's session.
  - Policies will be defined as: `CREATE POLICY tenant_isolation ON table_name USING (tenant_id = (auth.jwt() ->> 'tenant_id')::uuid);`

## 2. Myanmar Localization (L10n) & Typography
**Decision**: Use `Pyidaungsu` font capable of rendering Myanmar Unicode, and `intl` package for bilingual support.
**Reasoning**:
- **Market Requirement**: The primary market is Myanmar. Proper rendering of Burmese characters is critical for user acceptance.
- **Unicode vs. Zawgyi**: We strictly mandate **Unicode** (Pyidaungsu) and reject Zawgyi. This ensures future-proofing, standard compliance, and correct sorting/searching behavior in the database.
- **Fiscal Logic**: Myanmar currency (MMK) requires specific rounding rules (nearest 5 or 10 Kyat).
  - **Algorithm**: `(amount / 5.0).round() * 5`. This ensures standard rounding (1,232 -> 1,230; 1,233 -> 1,235).
  - **Implementation**: Centrally managed in `MmkRounding` extension to ensure consistency across UI and backend sync.
- **Offline-First**: Localization strings must be bundled with the app to function without internet.

## 3. Offline-First Architecture
**Decision**: Use `drift` (SQLite) for local storage and separate Sync Service.
**Reasoning**:
- **Infrastructure**: Internet connectivity in Myanmar can be intermittent. The POS must function 100% offline for sales and inventory.
- **Sync Strategy**: We use a custom "Version Vector" approach.
  - **Writes**: Always write to local SQLite first.
  - **Background Sync**: Push changes to Supabase when online.
  - **Conflict Resolution**: Last-Write-Wins (LWW) for simple fields; Additive merging for sales counters.

## 4. State Management
**Decision**: Riverpod 2.x (Generator Syntax).
**Reasoning**:
- **Type Safety**: Compile-time safety for providers.
- **Testability**: Easy detailed overrides for unit and widget tests.
- **Decoupling**: Separates UI from Business Logic (Controllers/Repositories).
