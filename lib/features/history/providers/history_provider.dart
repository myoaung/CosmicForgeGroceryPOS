import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/providers/database_provider.dart';
import 'package:drift/drift.dart';

final historyProvider = StateNotifierProvider<HistoryNotifier, AsyncValue<List<TransactionWithItems>>>((ref) {
  final db = ref.watch(databaseProvider);
  return HistoryNotifier(db);
});

class TransactionWithItems {
  final Transaction transaction;
  final List<TransactionItem> items;

  TransactionWithItems({required this.transaction, required this.items});
}

class HistoryNotifier extends StateNotifier<AsyncValue<List<TransactionWithItems>>> {
  final LocalDatabase _db;

  HistoryNotifier(this._db) : super(const AsyncValue.loading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      state = const AsyncValue.loading();
      
      // Fetch recent 50 transactions
      final transactions = await (_db.select(_db.transactions)
        ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
        ..limit(50))
        .get();

      final List<TransactionWithItems> history = [];

      for (var tx in transactions) {
        final items = await (_db.select(_db.transactionItems)
          ..where((t) => t.transactionId.equals(tx.id)))
          .get();
        
        history.add(TransactionWithItems(transaction: tx, items: items));
      }

      state = AsyncValue.data(history);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  Future<void> refresh() async {
    await loadHistory();
  }
}
