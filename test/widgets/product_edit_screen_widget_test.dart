import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/models/store.dart';
import 'package:grocery/core/providers/store_provider.dart';
import 'package:grocery/features/products/screens/product_edit_screen.dart';

void main() {
  testWidgets('product edit screen shows core form fields', (tester) async {
    final store = Store(
      id: 'store-1',
      tenantId: 'tenant-1',
      storeName: 'Yangon HQ',
      currencyCode: 'MMK',
      taxRate: 5,
      isGeofenceEnabled: false,
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeStoreProvider.overrideWith((ref) => store),
        ],
        child: const MaterialApp(
          home: ProductEditScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Product Name'), findsOneWidget);
    expect(find.text('Price (MMK)'), findsOneWidget);
    expect(find.text('Save Product'), findsOneWidget);
  });
}
