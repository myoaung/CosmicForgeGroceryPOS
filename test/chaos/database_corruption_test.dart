import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/services/backup_service.dart';
import 'package:path/path.dart' as p;

/// Chaos test: simulate corruption and ensure restore from latest backup.
void main() {
  test('recovers from corrupted SQLite using VACUUM INTO backup', () async {
    final tempDir = await Directory.systemTemp.createTemp('db_corrupt_test');
    final dbFile = File(p.join(tempDir.path, 'db.sqlite'));
    final backupService = BackupService(docsDirOverride: tempDir);

    // Create DB and seed a record
    final db = LocalDatabase.forTesting(NativeDatabase(dbFile));
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        id: 'p1',
        name: 'Sugar',
        price: 2000,
        stock: const drift.Value(5),
        unitType: 'UNIT',
      ),
    );

    // Take backup (VACUUM INTO)
    final backupFile = await backupService.backupDatabase(db);
    expect(backupFile, isNotNull);
    await db.close();

    // Corrupt the DB: truncate header
    final raf = dbFile.openSync(mode: FileMode.write);
    raf.writeFromSync(List.filled(100, 0));
    await raf.close();

    // Attempt to open corrupted DB should fail
    bool openFailed = false;
    try {
      final bad = LocalDatabase.forTesting(NativeDatabase(dbFile));
      await bad.customSelect('SELECT 1').get();
    } catch (_) {
      openFailed = true;
    }
    expect(openFailed, true);

    // Restore from backup to a fresh file (avoid locked original on Windows)
    final restoredFile = File(p.join(tempDir.path, 'db_restored.sqlite'));
    await backupService.restoreDatabase(backupFile!, targetFile: restoredFile);

    final restored = LocalDatabase.forTesting(NativeDatabase(restoredFile));
    final products = await restored.select(restored.products).get();
    expect(products.length, 1);
    expect(products.first.name, 'Sugar');
    await restored.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {
      // Ignore temp cleanup issues on Windows file locks in tests.
    }
  });
}
