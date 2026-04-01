import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/services/sync_service.dart';

/// Simulates rapid network flapping plus latency while ensuring the local write
/// commits and eventually syncs when connectivity stabilizes.
void main() {
  group('Sync resilience with latency + flapping network', () {
    late LocalDatabase db;
    late FakeGateway baseGateway;
    late LatencyDecorator gateway;
    late SyncService syncService;
    bool isOnline = false;

    setUp(() async {
      db = LocalDatabase.forTesting(NativeDatabase.memory());
      baseGateway = FakeGateway();
      gateway = LatencyDecorator(
        baseGateway,
        () => isOnline,
        delay: const Duration(milliseconds: 150),
      );
      syncService = SyncService(db, null, gateway);

      // Seed one pending transaction + item
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
    });

    tearDown(() async {
      await db.close();
    });

    test('offline first -> error, then recovers when online with latency', () async {
      // First attempt while offline should mark error, not crash.
      isOnline = false;
      await syncService.syncPendingTransactions();
      final errTx = await (db.select(db.transactions)..where((t) => t.id.equals('t1'))).getSingle();
      expect(errTx.syncStatus, 'error');

      // Flip online and allow gateway to respond with latency.
      isOnline = true;
      await syncService.syncPendingTransactions();

      final synced = await (db.select(db.transactions)..where((t) => t.id.equals('t1'))).getSingle();
      expect(synced.syncStatus, 'synced');
      expect(synced.lastSyncedAt, isNotNull);
      expect(baseGateway.txUpserts, 1);
      expect(baseGateway.itemUpserts, 1);
    });
  });
}

/// Base fake gateway that records calls.
class FakeGateway implements SyncGateway {
  int txUpserts = 0;
  int itemUpserts = 0;
  int productUpserts = 0;

  @override
  Future<void> upsertTransaction(Map<String, dynamic> payload) async {
    txUpserts++;
  }

  @override
  Future<void> upsertTransactionItems(List<Map<String, dynamic>> payload) async {
    itemUpserts += payload.length;
  }

  @override
  Future<void> upsertProduct(Map<String, dynamic> payload) async {
    productUpserts++;
  }
}

/// Decorator that adds latency and simulates connectivity flaps.
class LatencyDecorator implements SyncGateway {
  final SyncGateway _inner;
  final bool Function() _isOnline;
  final Duration delay;

  LatencyDecorator(this._inner, this._isOnline, {required this.delay});

  Future<void> _guarded(Future<void> Function() fn) async {
    if (!_isOnline()) throw Exception('offline');
    await Future.delayed(delay);
    await fn();
  }

  @override
  Future<void> upsertTransaction(Map<String, dynamic> payload) =>
      _guarded(() => _inner.upsertTransaction(payload));

  @override
  Future<void> upsertTransactionItems(List<Map<String, dynamic>> payload) =>
      _guarded(() => _inner.upsertTransactionItems(payload));

  @override
  Future<void> upsertProduct(Map<String, dynamic> payload) =>
      _guarded(() => _inner.upsertProduct(payload));
}
