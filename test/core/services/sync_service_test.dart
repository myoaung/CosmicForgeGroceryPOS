import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/services/sync_service.dart';
import 'package:matcher/matcher.dart' as m;

class FakeGateway implements SyncGateway {
  int txUpserts = 0;
  int productUpserts = 0;
  bool throwConflict = false;

  @override
  Future<void> upsertTransaction(Map<String, dynamic> payload) async {
    txUpserts++;
    if (throwConflict) {
      throw ConflictException('duplicate');
    }
  }

  @override
  Future<void> upsertTransactionItems(List<Map<String, dynamic>> payload) async {}

  @override
  Future<void> upsertProduct(Map<String, dynamic> payload) async {
    productUpserts++;
  }
}

void main() {
  late LocalDatabase db;
  late FakeGateway gateway;
  late SyncService syncService;

  setUp(() async {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeGateway();
    syncService = SyncService(db, null, gateway);
  });

  tearDown(() async {
    await db.close();
  });

  test('syncPendingTransactions is idempotent', () async {
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: 't1',
        storeId: 's1',
        tenantId: 'tenant',
        subtotal: 100,
        taxAmount: 5,
        totalAmount: 105,
        timestamp: DateTime.now(),
      ),
    );
    await db.into(db.transactionItems).insert(
      TransactionItemsCompanion.insert(
        transactionId: 't1',
        productId: 'p1',
        productName: 'Item',
        quantity: 1,
        unitPrice: 100,
        taxAmount: 5,
      ),
    );

    await syncService.syncPendingTransactions();
    await syncService.syncPendingTransactions(); // retry should not duplicate

    expect(gateway.txUpserts, 1);
    final tx = await (db.select(db.transactions)..where((t) => t.id.equals('t1'))).getSingle();
    expect(tx.syncStatus, 'synced');
    expect(tx.lastSyncedAt, m.isNotNull);
  });

  test('conflict sets syncStatus to conflict', () async {
    gateway.throwConflict = true;
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: 't_conflict',
        storeId: 's1',
        tenantId: 'tenant',
        subtotal: 50,
        taxAmount: 0,
        totalAmount: 50,
        timestamp: DateTime.now(),
      ),
    );

    await syncService.syncPendingTransactions();

    final tx = await (db.select(db.transactions)..where((t) => t.id.equals('t_conflict'))).getSingle();
    expect(tx.syncStatus, 'conflict');
    expect(tx.isDirty, true);
  });
}
