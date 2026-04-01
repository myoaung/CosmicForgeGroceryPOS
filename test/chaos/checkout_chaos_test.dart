import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/database/local_database.dart';

/// Chaos test: checkout must be atomic and idempotent.
void main() {
  group('Checkout chaos scenarios', () {
    late LocalDatabase db;

    setUp(() {
      db = LocalDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async => db.close());

    test('mid-checkout crash rolls back header and items', () async {
      final tx = TransactionsCompanion.insert(
        id: 't-crash',
        storeId: 'store-1',
        tenantId: 'tenant-1',
        subtotal: 100,
        taxAmount: 10,
        totalAmount: 110,
        timestamp: DateTime.now(),
      );
      final item = TransactionItemsCompanion.insert(
        transactionId: 't-crash',
        productId: 'p1',
        productName: 'Apple',
        quantity: 1,
        unitPrice: 100,
        taxAmount: 10,
      );

      // Simulate app kill/exception after header insert but before items complete.
      await expectLater(
        () async {
          await db.transaction(() async {
            await db.into(db.transactions).insert(tx);
            await db.into(db.transactionItems).insert(item);
            throw Exception('power loss mid-checkout');
          });
        },
        throwsA(isA<Exception>()),
      );

      final txCount = await db.select(db.transactions).get();
      final itemCount = await db.select(db.transactionItems).get();
      expect(txCount, isEmpty, reason: 'transaction header must rollback');
      expect(itemCount, isEmpty, reason: 'line items must rollback with header');
    });

    test('double-pay with same UUID does not duplicate records', () async {
      final tx = TransactionsCompanion.insert(
        id: 't-uuid',
        storeId: 'store-1',
        tenantId: 'tenant-1',
        subtotal: 50,
        taxAmount: 5,
        totalAmount: 55,
        timestamp: DateTime.now(),
      );
      final items = [
        TransactionItemsCompanion.insert(
          transactionId: 't-uuid',
          productId: 'p1',
          productName: 'Banana',
          quantity: 2,
          unitPrice: 20,
          taxAmount: 5,
        ),
      ];

      await db.transaction(() async {
        await db.into(db.transactions).insert(tx);
        for (final item in items) {
          await db.into(db.transactionItems).insert(item);
        }
      });

      // Second attempt with same UUID should be rejected by PK and leave data intact.
      await expectLater(
        () async {
          await db.transaction(() async {
            await db.into(db.transactions).insert(tx);
            for (final item in items) {
              await db.into(db.transactionItems).insert(item);
            }
          });
        },
        throwsA(isA<Exception>()),
      );

      final txRows = await db.select(db.transactions).get();
      final itemRows = await db.select(db.transactionItems).get();
      expect(txRows.length, 1);
      expect(itemRows.length, 1);
      expect(txRows.single.id, 't-uuid');
    });
  });
}
