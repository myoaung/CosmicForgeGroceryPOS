import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/providers/database_provider.dart';
import 'package:grocery/core/services/store_service.dart';
import 'package:grocery/core/providers/store_provider.dart';
import 'package:drift/drift.dart';

final dailyClosingProvider = StateNotifierProvider<DailyClosingNotifier, AsyncValue<DailyClosingReport>>((ref) {
  final db = ref.watch(databaseProvider);
  final storeService = ref.read(storeServiceProvider);
  return DailyClosingNotifier(db, storeService);
});

class DailyClosingReport {
  final double grossSales;
  final double totalTax;
  final double roundingDiff;
  final double netCash;
  final int transactionCount;
  final DateTime date;

  DailyClosingReport({
    required this.grossSales,
    required this.totalTax,
    required this.roundingDiff,
    required this.netCash,
    required this.transactionCount,
    required this.date,
  });
}

class DailyClosingNotifier extends StateNotifier<AsyncValue<DailyClosingReport>> {
  final LocalDatabase _db;
  final StoreService _storeService;

  DailyClosingNotifier(this._db, this._storeService) : super(const AsyncValue.loading());

  Future<void> generateReport() async {
    try {
      state = const AsyncValue.loading();

      // Security: Check Role (Mocked for now, assuming Manager)
      // if (!user.isManager) throw Exception('Access Denied');

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final transactions = await (_db.select(_db.transactions)
        ..where((t) => t.timestamp.isBetweenValues(startOfDay, endOfDay)))
        .get();

      double grossSales = 0;
      double totalTax = 0;
      double netCash = 0;

      for (var tx in transactions) {
        grossSales += tx.subtotal;
        totalTax += tx.taxAmount;
        netCash += tx.totalAmount;
      }

      // Rounding Diff = NetCash - (Gross + Tax)
      // E.g. (100 + 0) -> 100. Diff 0.
      // (103 + 5.15) = 108.15. Rounded to 110. Diff = 110 - 108.15 = 1.85.
      final roundingDiff = netCash - (grossSales + totalTax);

      final report = DailyClosingReport(
        grossSales: grossSales,
        totalTax: totalTax,
        roundingDiff: roundingDiff,
        netCash: netCash,
        transactionCount: transactions.length,
        date: now,
      );

      // Audit Log
      await _storeService.logAudit(actionType: 'VIEW_DAILY_REPORT', description: 'Generated report for ${now.toIso8601String()}');

      state = AsyncValue.data(report);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
