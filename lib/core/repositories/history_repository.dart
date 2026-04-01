import '../database/local_database.dart';
import 'package:drift/drift.dart';

class TransactionWithItems {
  final Transaction transaction;
  final List<TransactionItem> items;
  TransactionWithItems(this.transaction, this.items);
}

abstract class HistoryRepository {
  Future<List<TransactionWithItems>> fetchRecent({
    int limit,
    required String tenantId,
    String? storeId,
  });
}

class DriftHistoryRepository implements HistoryRepository {
  final LocalDatabase db;
  DriftHistoryRepository(this.db);

  @override
  Future<List<TransactionWithItems>> fetchRecent({
    int limit = 50,
    required String tenantId,
    String? storeId,
  }) async {
    final query = db.select(db.transactions)
      ..where((t) => t.tenantId.equals(tenantId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
      ])
      ..limit(limit);
    if (storeId != null && storeId.isNotEmpty) {
      query.where((t) => t.storeId.equals(storeId));
    }
    final transactions = await query.get();

    final List<TransactionWithItems> history = [];
    for (var tx in transactions) {
      final items = await (db.select(db.transactionItems)
            ..where((t) => t.transactionId.equals(tx.id)))
          .get();
      history.add(TransactionWithItems(tx, items));
    }
    return history;
  }
}
