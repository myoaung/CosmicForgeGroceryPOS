import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/features/reports/providers/report_provider.dart';
import 'package:grocery/core/services/store_service.dart';
import 'package:grocery/core/models/store.dart';

class MockStoreService implements StoreService {
  @override
  Store? get activeStore => null;

  @override
  Future<List<Store>> fetchStores() async => [];

  @override
  Future<bool> setActiveStore(Store store) async => true;

  @override
  Future<void> updateStoreTaxRate(String storeId, double newRate) async {}

  @override
  Future<void> logAudit({required String actionType, required String description}) async {}
  
  @override
  Future<bool> validateSecurity() async => true;
}

void main() {
  late LocalDatabase db;
  late DailyClosingNotifier reportNotifier;
  late MockStoreService mockStoreService;

  setUp(() async {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
    mockStoreService = MockStoreService();
    reportNotifier = DailyClosingNotifier(db, mockStoreService);
  });

  tearDown(() async {
    await db.close();
  });

  test('generateReport aggregates daily transactions correctly', () async {
    final now = DateTime.now();
    // 1. Transaction Today: Sub: 100, Tax: 0, Total: 100
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: 't1', 
        storeId: 's1', 
        tenantId: 'tn1', 
        subtotal: 100, 
        taxAmount: 0, 
        totalAmount: 100, 
        timestamp: now
      )
    );
     // 2. Transaction Today: Sub: 200, Tax: 10, Total: 210
    await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
            id: 't2',
            storeId: 's1',
            tenantId: 'tn1',
            subtotal: 200,
            taxAmount: 10,
            totalAmount: 210,
            timestamp: now
        )
    );
     // 3. Transaction Yesterday (Should be ignored)
    await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
            id: 't3',
            storeId: 's1',
            tenantId: 'tn1',
            subtotal: 500,
            taxAmount: 0,
            totalAmount: 500,
            timestamp: now.subtract(const Duration(days: 1))
        )
    );

    await reportNotifier.generateReport();
    
    final report = reportNotifier.state.value!;
    
    expect(report.transactionCount, 2);
    expect(report.grossSales, 300.0); // 100 + 200
    expect(report.totalTax, 10.0);
    expect(report.netCash, 310.0);
    expect(report.roundingDiff, 0.0); // 310 - (300+10) = 0
  });

   test('generateReport calculates rounding diff', () async {
    final now = DateTime.now();
    // Sub: 103, Tax: 5.15 -> Raw: 108.15. Total (Rounded): 110.
    // Diff should be 1.85
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: 't_round', 
        storeId: 's1', 
        tenantId: 'tn1', 
        subtotal: 103, 
        taxAmount: 5.15, 
        totalAmount: 110, 
        timestamp: now
      )
    );

    await reportNotifier.generateReport();
    final report = reportNotifier.state.value!;
    
    expect(report.grossSales, 103.0);
    expect(report.totalTax, 5.15);
    expect(report.netCash, 110.0);
    expect(report.roundingDiff, closeTo(1.85, 0.001)); 
  });
}
