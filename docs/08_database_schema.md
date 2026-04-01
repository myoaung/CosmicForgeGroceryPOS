# 8. Database Schema & Relationships

## 8.1 Schema Overview (Supabase + Drift)
The data models in Drift (Local) precisely mirror the structures inside Supabase PostgreSQL (Remote). 
*All multi-tenant tables enforce an immutable `tenant_id` column as a composite primary or foreign key.*

### 8.1.1 Core Tables
1. **`tenants`**
   - Stores root agency business data.
   - Encompasses `plan_type` and billing status.
2. **`stores`** 
   - A single `tenant` has a 1-to-Maybe relation with `stores` (Branches).
   - Contains BSSID, IPs, Tax Rates, and Geofencing limits.
3. **`users`**
   - Links the unique `auth.users.id` created by Supabase Auth with custom application roles (Admin, Manager, Cashier).
4. **`products`**
   - The central product catalog containing `price`, `sku`, `name`, and `barcode`.
5. **`inventory`**
   - `quantity` and ledger history synced to the `products` table.
6. **`orders` / `order_items` / `payments`**
   - A normalized trio for processing physical receipts. One `order` relates to multiple line items (`order_items`) and potentially multiple partial physical `payments`.
7. **`audit_logs`**
   - An immutable append-only ledger populated automatically by client events and database triggers. Tracks hardware state transitions, log-ins, edits, and high-value cashier deletes.

## 8.2 Drift Offline-First Mechanisms
Because the system is Offline-First, SQL schemas utilize a generic `SyncMixin` pattern that injects:
- `isDirty (boolean)`: Flag marking local records not yet propagated to Supabase.
- `lastSync (datetime)`: The exact timestamp of the final synced parity.
- `syncStatus (string)`: State machine for the queue (`pending`, `synced`, `conflict`).
- `version (integer)`: LWW incrementor to prevent older offline sync blocks from crushing newer online edits.
