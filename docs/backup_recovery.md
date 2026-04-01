# Database Backup & Recovery Guide

## 1. Purpose & Scope
This document outlines the automated backup and recovery procedures for the Grocery POS application. The system ensures `db.sqlite` is backed up daily to preventing data loss.

**Scope:**
- **Target:** Local SQLite Database (`db.sqlite`)
- **Location:** Internal App Documents Directory (`/backups/`)
- **Frequency:** Once daily on app startup
- **Platform:** Android (Primary), Windows (Dev)

## 2. Backup Location
Backups are stored in the application's secure documents directory. This directory is internal to the application and not accessible by other apps on non-rooted Android devices.

**Path Patterns:**
- `.../Documents/backups/grocery_pos_backup_YYYYMMDD_HHMM.sqlite`

## 3. Automated Backup Behavior
- **Trigger:** Runs automatically on cold app launch (splash screen).
- **Condition:** Runs only if `last_backup_date` != `today`.
- **Concurrency:** Runs **synchronously** in `main()` before the UI loads and before the database connection is opened. This ensures data consistency (no WAL file locks).

## 4. Retention Policy
The system automatically prunes old backups to save space.
- **Max Count:** Keeps the **10** most recent backups.
- **Max Age:** Deletes any backup older than **7 days**.

## 5. Restoration Procedure (Destructive)

> [!WARNING]
> **Data Loss Warning**
> Restoring a backup will **overwrite** the current database.
> The system automatically creates a `pre_restore_...` snapshot before overwriting, but caution is advised.

### Steps to Restore (Manual intervention required for now)
1.  **Close the Application** completely.
2.  **Locate Backup File:**
    - On Android, use a file explorer compatible with App Data (if debuggable) or use the specific "Restore" UI feature (not yet implemented).
    - For Developer/Admin restoration:
        1. Access device file system.
        2. Copy desired `grocery_pos_backup_....sqlite` to the root Documents folder.
        3. Rename it to `db.sqlite`.
        4. Restart the application.
3.  **Code-Level Restore (Future UI Feature):**
    - The `BackupService.restoreDatabase(File file)` method exists for future UI integration.
    - Calling this method requires an immediate app restart to reload the SQLite connection.

## 6. Troubleshooting

| Issue | Cause | Resolution |
| :--- | :--- | :--- |
| **Backup skipped** | App was not closed/restarted (hot restart doesn't count if main() isn't re-run in some environments). | Kill the app and relaunch. |
| **Space Full** | Device storage full. | Clear space. Pruning tries to keep size low, but initial space is needed. |
| **Corrupt Backup** | App crashed *during* file write. | Check the next available backup. SQLite files are single files, so partial writes = corruption. |

## 7. Developer Notes
- **Safety:** Backup runs before `runApp()`.
- **Dependencies:** `path_provider`, `shared_preferences`.
- **Class:** `lib/core/services/backup_service.dart`.
