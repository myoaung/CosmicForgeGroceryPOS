import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../database/local_database.dart';

class BackupService {
  static const String _backupDirName = 'backups';
  static const String _dbFileName = 'db.sqlite';
  static const int _maxBackups = 10;
  static const int _retentionDays = 7;
  final Directory? docsDirOverride;

  BackupService({this.docsDirOverride});

  /// Performs a backup of the main SQLite database using VACUUM INTO.
  /// 
  /// This requires the [db] to be open.
  Future<File?> backupDatabase(LocalDatabase db) async {
    try {
      final docsDir = docsDirOverride ?? await getApplicationDocumentsDirectory();
      
      final backupDir = Directory(p.join(docsDir.path, _backupDirName));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final backupPath = p.join(backupDir.path, 'grocery_pos_backup_$timestamp.sqlite');
      final backupFile = File(backupPath);

      // Integrity check before writing backup
      final result = await db.customSelect('PRAGMA integrity_check').getSingle();
      final status = result.read<String>('integrity_check');
      if (status.toLowerCase() != 'ok') {
        throw Exception('Integrity check failed: $status');
      }

      // Execute Safe Backup via VACUUM INTO
      final escapedPath = backupPath.replaceAll("'", "''");
      await db.customStatement("VACUUM INTO '$escapedPath'");
      debugPrint('BackupService: Database backed up to $backupPath');
      return backupFile;

    } catch (e) {
      debugPrint('BackupService Error: $e');
      // Fail gracefully as per requirements
      return null;
    }
  }

  /// Prunes old backups based on count and age.
  Future<void> pruneOldBackups() async {
    try {
      final docsDir = docsDirOverride ?? await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(docsDir.path, _backupDirName));

      if (!await backupDir.exists()) return;

      final List<FileSystemEntity> files = await backupDir.list().toList();
      final List<File> backupFiles = files.whereType<File>().where((f) {
        return p.basename(f.path).startsWith('grocery_pos_backup_') &&
               p.basename(f.path).endsWith('.sqlite');
      }).toList();

      // Sort by modification time (newest first)
      // Note: File names contain timestamp, so sorting by name desc matches time desc 
      // if modification time is unreliable, but mod time is safer.
      backupFiles.sort((a, b) {
        final timeComparison = b.lastModifiedSync().compareTo(a.lastModifiedSync());
        if (timeComparison != 0) return timeComparison;
        // Fallback to filename descending (assuming timestamp usage in name)
        return p.basename(b.path).compareTo(p.basename(a.path));
      });

      debugPrint('BackupService: Found ${backupFiles.length} backups.');

      for (int i = 0; i < backupFiles.length; i++) {
        final file = backupFiles[i];
        bool shouldDelete = false;

        // Rule 1: Keep MAX 10
        if (i >= _maxBackups) {
          shouldDelete = true;
          debugPrint('BackupService: Pruning ${p.basename(file.path)} (Exceeds count limit)');
        } 
        // Rule 2: Delete older than 7 days
        else {
          final age = DateTime.now().difference(await file.lastModified());
          if (age.inDays > _retentionDays) {
            shouldDelete = true;
            debugPrint('BackupService: Pruning ${p.basename(file.path)} (Older than $_retentionDays days)');
          }
        }

        if (shouldDelete) {
          await file.delete();
        }
      }

    } catch (e) {
      debugPrint('BackupService Prune Error: $e');
    }
  }

  /// Restores the database from a specific backup file.
  /// 
  /// WARNING: This is destructive. It overwrites the current database.
  /// The app should strictly be restarted after this operation.
  Future<void> restoreDatabase(File backupFile, {File? targetFile}) async {
    if (!await backupFile.exists()) {
      throw Exception('Backup file not found');
    }

    final docsDir = docsDirOverride ?? await getApplicationDocumentsDirectory();
    final dbFile = targetFile ?? File(p.join(docsDir.path, _dbFileName));

    // Safety: Auto-backup current state before restore
    if (await dbFile.exists()) {
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final preRestoreBackup = p.join(docsDir.path, _backupDirName, 'pre_restore_$timestamp.sqlite');
      await dbFile.copy(preRestoreBackup);
      debugPrint('BackupService: Current DB saved to $preRestoreBackup before restore.');
    }

    // Atomic-ish Replace
    // If copy-over fails because file exists, delete then copy.
    if (await dbFile.exists()) {
      final tmp = File('${dbFile.path}.old');
      try {
        await dbFile.rename(tmp.path);
      } catch (_) {
        await dbFile.delete();
      }
      await backupFile.copy(dbFile.path);
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
    } else {
      await backupFile.copy(dbFile.path);
    }
    debugPrint('BackupService: Database restored from ${backupFile.path}');
  }
}
