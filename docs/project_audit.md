# Project Audit — Cosmic Forge Grocery POS
*Last updated: 2026-02-18 (UTC)*

## Objective
Define the legal and technical “Source of Truth” and reconciliation flow for offline-first financial data to ensure zero leakage between local and cloud stores.

## Data Sovereignty
- **Primary Source of Truth:** Local SQLite (Drift). All `TransactionUUID`s are generated client-side to avoid collisions.
- **Secondary (Reporting/Aggregation):** Supabase (PostgreSQL) for multi-terminal rollups and dashboards.

## Reconciliation Flow
1. **Transaction Finalized:** Local record created with `syncStatus='pending'`, `isDirty=true`, `client_timestamp`.
2. **Sync Trigger:** `SyncService` attempts push to Supabase.
3. **Conflict Resolution:** If the same UUID exists in Supabase with differing data, the **earliest `client_timestamp` wins** for financial records (deterministic LWW).
4. **Verification:** Daily EOD checksum comparing local transaction count vs. cloud records. Mismatches are logged for manual review.

## Audit Evidence & Compliance
- Local-to-cloud parity proven via EOD checksum logs (to be appended in future runs).
- Backup integrity: VACUUM INTO + `PRAGMA integrity_check` (covered in `backup_restore_test.dart`).
- Secrets: rotation and CI verification tracked in `docs/ci_secrets_verification.md`.

## Recovery Objectives
- **RPO (Recovery Point Objective):** Target < 5 minutes of data loss; bounded by last successful sync. Offline transactions are preserved locally; cloud lag is tolerated but reconciled by UUID + timestamp.
- **RTO (Recovery Time Objective):** Manual restore from backup expected within 15 minutes on a single device (VACUUM INTO snapshot).

## Corrupted SQLite Recovery (Using VACUUM INTO Backups)
1. Detect corruption via failed `PRAGMA integrity_check` or app startup failure.
2. Locate latest backup in `Documents/backups/grocery_pos_backup_*.sqlite`.
3. Copy backup to `db.sqlite` (app documents directory) after taking an automatic pre-restore snapshot.
4. Relaunch app; run EOD checksum to confirm parity with Supabase; resync pending records.

## Outstanding Architecture Items (to close in P2)
- Verify remaining screens/widgets have no direct Drift imports; enforce repository/use-case boundary across the presentation layer.

## Change Log
- 2026-02-18: Initial audit doc drafted; reconciliation rules documented; architecture gap noted for product_edit_screen.
