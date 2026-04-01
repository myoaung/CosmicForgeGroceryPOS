# 10. Business Workflows & Product Features

## 10.1 Daily Morning Setup
1. **Cashier Boot**: Application opens. `SecurityGuard` verifies BSSID and GPS. Evaluates against `100m` active store geofence.
2. **Authentication**: Cashier inputs 6-digit local hardware PIN.
3. **Synchronization**: `SyncService` wakes and fetches any pricing or catalog changes issued by the Tenant Admin overnight via the Vercel Supabase pipeline.

## 10.2 Customer Transaction Flow
1. **Product Scan**: Cashier scans barcodes or manually taps large visual squares in `POSLayout`.
2. **Pricing Aggregation**: `CartNotifier` calculates base costs, evaluates multi-tier bulk pricing, exempts specific items from standard `taxRates`, and rounds the final sum to the nearest `5 Kyat` (MMK logic limit).
3. **Checkout Finalization**: Cashier clicks "PAY". `CheckoutUseCase` generates a single unified Drift SQLite atomic transaction linking `orders`, `order_items`, and inventory depletion.
4. **Queue Enqueue**: The transaction is flagged as `isDirty=true` and instantly placed in the `SyncQueueWorker`.
5. **Printer Hardware**: The app interfaces with the Bluetooth thermal printer via `ESC/POS`, generating a physical localized Unicode receipt for the patron.

## 10.3 Evening Reconciliation
1. **Network Sync**: The `SyncQueueWorker` batches all daily LWW payloads.
2. **Dead Letter Recovery**: If edge cases or network splits resulted in 400 validations, Manager inputs an override code, manually investigating `dead_letter` status rows within the local Admin panel.
3. **Audit Closure**: Telemetry for offline duration and sync latencies are batched securely to `ObservabilityService` sinks, and device locks itself down.
