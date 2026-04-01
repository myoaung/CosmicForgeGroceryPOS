import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:matcher/matcher.dart' as m;
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/services/backup_service.dart';
import 'package:path/path.dart' as p;

void main() {
  test('backup integrity check and restore roundtrip', () async {
    final tempDir = await Directory.systemTemp.createTemp('backup_restore_test');
    final dbFile = File(p.join(tempDir.path, 'db.sqlite'));
    final db = LocalDatabase.forTesting(NativeDatabase(dbFile));

    await db.into(db.products).insert(
      ProductsCompanion.insert(
        id: 'prod-1',
        name: 'Sugar',
        price: 2000,
        stock: const Value(10),
        unitType: 'UNIT',
      ),
    );

    final backupService = BackupService(docsDirOverride: tempDir);
    final backupFile = await backupService.backupDatabase(db);
    expect(backupFile, m.isNotNull);
    expect(await backupFile!.exists(), true);

    await db.close();

    final restoredFile = File(p.join(tempDir.path, 'restored.sqlite'));
    await backupService.restoreDatabase(backupFile, targetFile: restoredFile);

    final restoredDb = LocalDatabase.forTesting(NativeDatabase(restoredFile));
    final products = await restoredDb.select(restoredDb.products).get();
    expect(products.length, 1);
    expect(products.first.name, 'Sugar');
    await restoredDb.close();
    await tempDir.delete(recursive: true);
  });
}
