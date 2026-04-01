import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/models/store.dart';
import 'package:grocery/core/providers/database_provider.dart';
import 'package:grocery/core/providers/store_provider.dart';
import 'package:grocery/core/services/store_service.dart';
import 'package:grocery/features/pos/screens/pos_screen.dart';

class _FakeStoreService extends StoreService {
  _FakeStoreService(this._store) : super(sessionValidator: () async => true);

  final Store _store;

  @override
  Store? get activeStore => _store;

  @override
  Future<bool> validateSecurity() async => true;
}

void main() {
  testWidgets('checkout button is visible on POS layout', (tester) async {
    final db = LocalDatabase.forTesting(NativeDatabase.memory());
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
          databaseProvider.overrideWithValue(db),
          storeServiceProvider.overrideWithValue(_FakeStoreService(store)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: POSLayout(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('PAY & PRINT'), findsOneWidget);
    await db.close();
  });
}
