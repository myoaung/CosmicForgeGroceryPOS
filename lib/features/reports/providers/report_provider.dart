import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery/core/providers/database_provider.dart';
import 'package:grocery/core/services/store_service.dart';
import 'package:grocery/core/providers/store_provider.dart';
import 'package:grocery/core/repositories/report_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final dailyClosingProvider =
    StateNotifierProvider<DailyClosingNotifier, AsyncValue<DailyClosingReport>>(
        (ref) {
  final db = ref.watch(databaseProvider);
  final repo = DriftReportRepository(db);
  final storeService = ref.read(storeServiceProvider);
  final scope = ref.watch(activeTenantStoreScopeProvider);
  return DailyClosingNotifier(
    repo,
    storeService,
    tenantId: scope?.tenantId,
    storeId: scope?.storeId,
  );
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

class DailyClosingNotifier
    extends StateNotifier<AsyncValue<DailyClosingReport>> {
  final ReportRepository _repo;
  final StoreService _storeService;
  final String? _tenantId;
  final String? _storeId;

  DailyClosingNotifier(
    this._repo,
    this._storeService, {
    String? tenantId,
    String? storeId,
  })  : _tenantId = tenantId,
        _storeId = storeId,
        super(const AsyncValue.loading());

  Future<void> generateReport() async {
    try {
      state = const AsyncValue.loading();
      final tenantId = _tenantId;
      if (tenantId == null || tenantId.isEmpty) {
        throw StateError('No active tenant scope for report generation.');
      }

      // Security: Check Role (Mocked for now, assuming Manager)
      // if (!user.isManager) throw Exception('Access Denied');

      final now = DateTime.now();
      double grossSales = 0;
      double totalTax = 0;
      double netCash = 0;
      int transactionCount = 0;

      // OPERATION ORACLE RSK-02: Target Edge Function first to save client-side memory
      bool edgeSuccess = false;
      try {
        final res = await Supabase.instance.client.functions.invoke('z_report');
        if (res.status == 200 && res.data != null) {
          final data = res.data['z_report'] ?? {};
          grossSales = (data['gross_sales'] ?? 0).toDouble();
          totalTax = (data['total_tax'] ?? 0).toDouble();
          netCash = (data['net_cash'] ?? 0).toDouble();
          transactionCount = (data['transaction_count'] ?? 0) as int;
          edgeSuccess = true;
        }
      } catch (e) {
        // Offline or Network Failure -> gracefully fallback to local heavy calculation
        edgeSuccess = false;
      }

      if (!edgeSuccess) {
        final transactions = (await _repo.fetchTransactionsForDay(
          now,
          tenantId: tenantId,
          storeId: _storeId,
        )).transactions;

        transactionCount = transactions.length;
        for (var tx in transactions) {
          grossSales += tx.subtotal;
          totalTax += tx.taxAmount;
          netCash += tx.totalAmount;
        }
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
        transactionCount: transactionCount,
        date: now,
      );

      // Audit Log
      await _storeService.logAudit(
          actionType: 'VIEW_DAILY_REPORT',
          description: 'Generated report for ${now.toIso8601String()} (Edge: $edgeSuccess)');

      state = AsyncValue.data(report);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
