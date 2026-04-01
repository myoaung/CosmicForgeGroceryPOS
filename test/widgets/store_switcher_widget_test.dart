import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/models/store.dart';
import 'package:grocery/core/providers/store_provider.dart';
import 'package:grocery/features/dashboard/store_switcher.dart';

void main() {
  testWidgets('store switcher renders dropdown with store list', (tester) async {
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
          storesListProvider.overrideWith((ref) async => [store]),
          activeStoreProvider.overrideWith((ref) => store),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: StoreSwitcher(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Active Store Context'), findsOneWidget);
    expect(find.text('Yangon HQ'), findsWidgets);
  });
}
