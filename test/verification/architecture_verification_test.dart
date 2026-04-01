
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:matcher/matcher.dart' as m;
import 'package:drift/native.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/services/backup_service.dart';
import 'package:path/path.dart' as p;

// Evidence Verification Test Suite
void main() {
  late LocalDatabase db;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pos_verification_');
    final file = File(p.join(tempDir.path, 'db.sqlite'));
    db = LocalDatabase.forTesting(NativeDatabase(file));
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  group('Architecture Evidence >', () {
    
    // Evidence Item 1: Backup Safety (VACUUM INTO)
    test('BackupService performs valid VACUUM INTO backup', () async {
      // Arrange: Seed DB
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          id: 'test-backup', name: 'Backup Item', price: 100, unitType: 'UNIT'
        )
      );

      // Act: Perform Backup
      final backupService = BackupService(docsDirOverride: tempDir);
      final backupFile = await backupService.backupDatabase(db);

      // Assert: Verify File Exists and is Valid SQLite
      expect(backupFile, m.isNotNull);
      expect(await backupFile!.exists(), true);
      expect(await backupFile.length(), greaterThan(0));

      // Assert: Verify Integrity by opening backup
      final backupDb = LocalDatabase.forTesting(NativeDatabase(backupFile));
      final items = await backupDb.select(backupDb.products).get();
      expect(items.length, 1);
      expect(items.first.name, 'Backup Item');
      await backupDb.close();
    });

    // Evidence Item 2: DB Indices and required columns
    test('Database has required offline-first columns and indices', () async {
      final tableInfo = await db.customSelect(
        "PRAGMA table_info('products')"
      ).get();
      final columns = tableInfo.map((row) => row.read<String>('name')).toSet();
      expect(columns.containsAll([
        'created_at',
        'updated_at',
        'is_dirty',
        'sync_status',
        'last_synced_at'
      ]), true, reason: 'Products missing offline-first metadata columns');

      final result = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='products'"
      ).get();
      final indices = result.map((row) => row.read<String>('name')).toSet();

      expect(indices.contains('products_updated_at_idx'), true, reason: 'Missing updatedAt index');
      expect(indices.contains('products_is_dirty_idx'), true, reason: 'Missing isDirty index');
      expect(indices.contains('products_sync_status_idx'), true, reason: 'Missing syncStatus index');

      final syncQueueInfo = await db.customSelect(
        "PRAGMA table_info('sync_queues')"
      ).get();
      final syncColumns = syncQueueInfo.map((row) => row.read<String>('name')).toSet();
      expect(syncColumns.containsAll([
        'entity_type',
        'entity_id',
        'operation',
        'payload',
        'retry_count',
        'status',
        'last_attempt_at',
      ]), true, reason: 'sync_queues missing required retry/queue columns');
    });

    // Evidence Item 3: Sync Optimization (isDirty + syncStatus)
    test('Products set isDirty & syncStatus defaults and updates', () async {
      await db.into(db.products).insert(
        ProductsCompanion.insert(
          id: 'sync-test', name: 'Sync Item', price: 200, unitType: 'UNIT'
        )
      );

      final product = await (db.select(db.products)..where((t) => t.id.equals('sync-test'))).getSingle();
      expect(product.isDirty, true);
      expect(product.syncStatus, 'pending'); 

      await (db.update(db.products)..where((t) => t.id.equals('sync-test'))).write(
        const ProductsCompanion(isDirty: Value(false), syncStatus: Value('synced'))
      );
      
      final cleanProduct = await (db.select(db.products)..where((t) => t.id.equals('sync-test'))).getSingle();
      expect(cleanProduct.isDirty, false);
      expect(cleanProduct.syncStatus, 'synced');
    });
  });
}
