import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/features/pos/providers/cart_provider.dart';
import 'package:grocery/core/services/sync_service.dart';
import 'package:grocery/core/repositories/cart_repository.dart';
import 'package:grocery/core/usecases/checkout_use_case.dart';
import 'package:grocery/core/auth/session_context.dart';

class _NoOpSyncService extends SyncService {
  _NoOpSyncService(LocalDatabase db) : super(db, null, null);

  @override
  Future<void> syncPendingTransactions() async {}
}

void main() {
  late LocalDatabase db;
  late CartNotifier cartNotifier;

  setUp(() async {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
    final cartRepo = DriftCartRepository(db);
    final checkout = CheckoutUseCase(db);
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'p1',
            tenantId: const Value('t1'),
            storeId: const Value('s1'),
            name: 'Rice',
            price: 100,
            stock: const Value(5),
            unitType: 'UNIT',
            isTaxExempt: const Value(true),
          ),
        );
    cartNotifier = CartNotifier(
      cartRepo, 
      checkout, 
      5.0, 
      _NoOpSyncService(db),
      tenantId: 't1',
      storeId: 's1',
      sessionContext: const SessionContext(
        isAuthenticated: true,
        userId: 'u1',
        tenantId: 't1',
        storeId: 's1',
        role: UserRole.cashier,
        deviceId: 'd1',
        sessionId: 'sess1',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('checkout rolls back when stock is insufficient', () async {
    final product = await (db.select(db.products)
          ..where((p) => p.id.equals('p1')))
        .getSingle();
    await cartNotifier.addToCart(product, tenantId: 't1', storeId: 's1');
    await cartNotifier.addToCart(product, tenantId: 't1', storeId: 's1');
    await cartNotifier.addToCart(product, tenantId: 't1', storeId: 's1');
    await cartNotifier.addToCart(product, tenantId: 't1', storeId: 's1');
    await cartNotifier.addToCart(product, tenantId: 't1', storeId: 's1');
    // cart quantity = 5, stock =5 -> OK
    // increase to exceed stock
    await cartNotifier.addToCart(product,
        tenantId: 't1', storeId: 's1'); // now quantity 6

    expect(
      () => cartNotifier.checkout(),
      throwsA(isA<Exception>()),
    );

    final txs = await db.select(db.transactions).get();
    expect(txs, isEmpty);

    final refreshedProduct = await (db.select(db.products)
          ..where((p) => p.id.equals('p1')))
        .getSingle();
    expect(refreshedProduct.stock, 5); // unchanged
  });

  test('checkout deducts stock atomically', () async {
    final product = await (db.select(db.products)
          ..where((p) => p.id.equals('p1')))
        .getSingle();
    await cartNotifier.addToCart(product, tenantId: 't1', storeId: 's1');
    await cartNotifier.addToCart(product,
        tenantId: 't1', storeId: 's1'); // quantity 2

    await cartNotifier.checkout();

    final txs = await db.select(db.transactions).get();
    expect(txs.length, 1);

    final refreshedProduct = await (db.select(db.products)
          ..where((p) => p.id.equals('p1')))
        .getSingle();
    expect(refreshedProduct.stock, 3); // 5 - 2
  });
}
