import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/repositories/product_repository.dart';

void main() {
  late LocalDatabase db;
  late DriftProductRepository repo;

  setUp(() async {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
    repo = DriftProductRepository(db);

    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'p-1',
            tenantId: const Value('tenant-1'),
            storeId: const Value('store-1'),
            name: 'Tenant1 Product',
            price: 100,
            unitType: 'UNIT',
          ),
        );
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'p-2',
            tenantId: const Value('tenant-2'),
            storeId: const Value('store-2'),
            name: 'Tenant2 Product',
            price: 100,
            unitType: 'UNIT',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('watchAll returns only products in requested tenant/store scope',
      () async {
    final scoped =
        await repo.watchAll(tenantId: 'tenant-1', storeId: 'store-1').first;
    expect(scoped.length, 1);
    expect(scoped.first.id, 'p-1');
  });

  test('delete does not remove product outside tenant scope', () async {
    await repo.delete('p-2', tenantId: 'tenant-1', storeId: 'store-1');
    final stillExists = await (db.select(db.products)
          ..where((p) => p.id.equals('p-2')))
        .getSingleOrNull();
    expect(stillExists, isNot(equals(null)));
  });
}
