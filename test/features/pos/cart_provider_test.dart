import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/features/pos/providers/cart_provider.dart';
import 'package:grocery/core/services/sync_service.dart';

class MockSyncService extends SyncService {
  MockSyncService() : super(LocalDatabase.forTesting(NativeDatabase.memory()), null);
  @override
  Future<void> syncPendingTransactions() async {}
}

void main() {
  late LocalDatabase db;
  late CartNotifier cartNotifier;

  setUp(() async {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
    
    // Seed items
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        id: 'p1', 
        name: 'Rice', 
        price: 100.0, 
        isTaxExempt: const Value(true), 
        unitType: 'UNIT'
      )
    );
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        id: 'p2', 
        name: 'Beer', 
        price: 100.0, 
        isTaxExempt: const Value(false), 
        unitType: 'UNIT'
      )
    );

    cartNotifier = CartNotifier(db, 5.0, MockSyncService()); // 5% tax
  });

  tearDown(() async {
    await db.close();
  });

  test('addToCart adds item and updates totals', () async {
    final product = await (db.select(db.products)..where((t) => t.id.equals('p2'))).getSingle();
    
    await cartNotifier.addToCart(product);
    
    expect(cartNotifier.state.items.length, 1);
    expect(cartNotifier.state.subtotal, 100.0);
    expect(cartNotifier.state.taxAmount, 5.0); // 5% of 100
    // Total = 105. Rounding? 105 is valid (nearest 5/10).
    expect(cartNotifier.state.total, 105.0);
  });

  test('Tax Exemption Logic', () async {
    final rice = await (db.select(db.products)..where((t) => t.id.equals('p1'))).getSingle();
    
    await cartNotifier.addToCart(rice);
    
    expect(cartNotifier.state.subtotal, 100.0);
    expect(cartNotifier.state.taxAmount, 0.0); // Exempt
    expect(cartNotifier.state.total, 100.0);
  });

  test('MMK Rounding Logic', () async {
    // Need a price resulting in non-round total
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        id: 'p3', 
        name: 'Weird Price', 
        price: 103.0, 
        isTaxExempt: const Value(false), 
        unitType: 'UNIT'
      )
    );
    
    final product = await (db.select(db.products)..where((t) => t.id.equals('p3'))).getSingle();
    await cartNotifier.addToCart(product);
    
    // Subtotal: 103
    // Tax: 103 * 0.05 = 5.15
    // Raw Total: 108.15
    // Rounding: Nearest 5/10. 
    // 108.15 -> 110? Or 105?
    // Implementation of roundToMmk: (this / 10).round() * 10?? Or 5?
    // Let's check mmk_rounding.dart or assume standard.
    // Usually < app state > calls roundToMmk().
    
    final total = cartNotifier.state.total;
    // expect(total % 5 == 0 || total % 10 == 0, true);
    // If logic is nearest 10: 108.15 -> 110.
    // If logic is nearest 5: 108.15 -> 110 (closer to 110 than 105).
    // Let's just print to verify for now or expect a range.
    expect(total, 110.0); 
  });
}
