import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/services/backup_service.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late BackupService backupService;
  late LocalDatabase db;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('backup_test_');
    backupService = BackupService(docsDirOverride: tempDir);
    final dbFile = File(p.join(tempDir.path, 'db.sqlite'));
    db = LocalDatabase.forTesting(NativeDatabase(dbFile));
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('backupDatabase creates a backup file when db.sqlite exists', () async {
    await db.into(db.products).insert(
      ProductsCompanion.insert(id: 'p1', name: 'Item', price: 1000, unitType: 'UNIT'),
    );

    final backupFile = await backupService.backupDatabase(db);

    final backupDir = Directory(p.join(tempDir.path, 'backups'));
    expect(await backupDir.exists(), isTrue);
    final files = await backupDir.list().toList();
    expect(files.length, 1);
    expect(p.basename(files.first.path), startsWith('grocery_pos_backup_'));
    expect(files.first.path, endsWith('.sqlite'));
    expect(backupFile, isNotNull);
  });

  test('pruneOldBackups removes oldest files when count > 10', () async {
    final backupDir = Directory(p.join(tempDir.path, 'backups'));
    await backupDir.create();

    // Create 12 backup files
    // We name them with index to distinguish, and sleep to enforce mod time order
    for (int i = 0; i < 12; i++) {
        final timestamp = i.toString().padLeft(4, '0'); // 0000, 0001, ...
        final file = File(p.join(backupDir.path, 'grocery_pos_backup_20240101_$timestamp.sqlite'));
        await file.writeAsString('Backup $i');
        // Sleep 50ms to ensure modification time diff is significant for FS
        await Future.delayed(const Duration(milliseconds: 50));
    }

    var files = await backupDir.list().toList();
    expect(files.length, 12);

    await backupService.pruneOldBackups();

    files = await backupDir.list().toList();
    expect(files.length, 10);
    
    // Check remaining files. Logic preserves NEWEST (latest mod time).
    // The loop creates files sequentially, so last created (index 11) is newest.
    // Index 0 ('...0000.sqlite') is oldest.
    
    final remainingNames = files.map((f) => p.basename(f.path)).toList();
    
    bool hasOldest = remainingNames.any((n) => n.contains('_0000.sqlite'));
    bool hasNewest = remainingNames.any((n) => n.contains('_0011.sqlite'));
    
    expect(hasOldest, isFalse, reason: 'Oldest file (0000) should be pruned');
    expect(hasNewest, isTrue, reason: 'Newest file (0011) should be kept');
  });
}
