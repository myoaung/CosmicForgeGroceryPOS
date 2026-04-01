import '../database/local_database.dart';
import 'package:drift/drift.dart';

class DailyReportResult {
  final List<Transaction> transactions;
  DailyReportResult(this.transactions);
}

abstract class ReportRepository {
  Future<DailyReportResult> fetchTransactionsForDay(
    DateTime day, {
    required String tenantId,
    String? storeId,
  });
}

class DriftReportRepository implements ReportRepository {
  final LocalDatabase db;
  DriftReportRepository(this.db);

  @override
  Future<DailyReportResult> fetchTransactionsForDay(
    DateTime day, {
    required String tenantId,
    String? storeId,
  }) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final query = db.select(db.transactions)
      ..where((t) =>
          t.timestamp.isBetweenValues(startOfDay, endOfDay) &
          t.tenantId.equals(tenantId));
    if (storeId != null && storeId.isNotEmpty) {
      query.where((t) => t.storeId.equals(storeId));
    }

    final txs = await query.get();
    return DailyReportResult(txs);
  }
}
