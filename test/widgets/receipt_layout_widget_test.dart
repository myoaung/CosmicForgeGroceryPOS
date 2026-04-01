import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/features/receipt/widgets/receipt_layout.dart';

void main() {
  testWidgets('receipt layout renders store and total', (tester) async {
    final tx = Transaction(
      id: 'tx-12345678',
      storeId: 'store-1',
      tenantId: 'tenant-1',
      subtotal: 100,
      taxAmount: 5,
      totalAmount: 105,
      timestamp: DateTime(2026, 3, 8, 10, 0),
      createdAt: DateTime(2026, 3, 8, 10, 0),
      updatedAt: DateTime(2026, 3, 8, 10, 0),
      isDirty: true,
      syncStatus: 'pending',
      lastSyncedAt: null,
    );

    final items = [
      TransactionItem(
        id: 1,
        tenantId: 'tenant-1',
        storeId: 'store-1',
        transactionId: 'tx-1',
        productId: 'p1',
        productName: 'Tea',
        quantity: 1,
        unitPrice: 100,
        taxAmount: 5,
        createdAt: DateTime(2026, 3, 8, 10, 0),
        updatedAt: DateTime(2026, 3, 8, 10, 0),
        isDirty: true,
        syncStatus: 'pending',
        lastSyncedAt: null,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReceiptLayout(
            transaction: tx,
            items: items,
            storeName: 'Yangon HQ',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Yangon HQ'), findsOneWidget);
    expect(find.text('Total:'), findsOneWidget);
    expect(find.text('105'), findsWidgets);
  });
}
