import 'package:drift/drift.dart' as drift;
import '../database/local_database.dart';

/// Placeholder repository for reports/analytics to keep UI decoupled from Drift.
abstract class ReportsRepository {
  Future<List<Transaction>> fetchDailySales(DateTime day);
  Future<double> fetchTotalTax(DateTime day);
}

class DriftReportsRepository implements ReportsRepository {
  final LocalDatabase db;
  DriftReportsRepository(this.db);

  @override
  Future<List<Transaction>> fetchDailySales(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return (db.select(db.transactions)
          ..where((t) =>
              t.timestamp.isBiggerOrEqualValue(start) &
              t.timestamp.isSmallerThanValue(end)))
        .get();
  }

  @override
  Future<double> fetchTotalTax(DateTime day) async {
    final sales = await fetchDailySales(day);
    return sales.fold<double>(0, (sum, tx) => sum + tx.taxAmount);
  }
}
