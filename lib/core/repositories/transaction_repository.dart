import '../database/local_database.dart';

abstract class TransactionRepository {
  Future<void> insertTransactionWithItems({
    required TransactionsCompanion transaction,
    required List<TransactionItemsCompanion> items,
  });
}

class DriftTransactionRepository implements TransactionRepository {
  final LocalDatabase db;
  DriftTransactionRepository(this.db);

  @override
  Future<void> insertTransactionWithItems({
    required TransactionsCompanion transaction,
    required List<TransactionItemsCompanion> items,
  }) async {
    await db.transaction(() async {
      await db.into(db.transactions).insert(transaction);
      for (final item in items) {
        await db.into(db.transactionItems).insert(item);
      }
    });
  }
}
