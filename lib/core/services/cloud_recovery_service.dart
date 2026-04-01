import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_database.dart';
import 'package:drift/drift.dart';

class CloudRecoveryService {
  final LocalDatabase _db;
  final SupabaseClient? _supabase; // Optional for offline-first resilience

  CloudRecoveryService(this._db, this._supabase);

  /// Checks if local DB is empty, and if so, fetches data from Cloud.
  Future<void> recoverTransactions() async {
    if (_supabase == null) return;

    final countExp = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)..addColumns([countExp]);
    final result = await query.map((row) => row.read(countExp)).getSingle();

    if (result != null && result > 0) {
      // Local data exists, skip recovery to avoid duplicates/conflicts
      return; 
    }

    try {
      final response = await _supabase /* Checked above */
          .from('transactions')
          .select('*, transaction_items(*)')
          .gte('timestamp', DateTime.now().subtract(const Duration(days: 30)).toIso8601String())
          .order('timestamp', ascending: false);
      
      final List<dynamic> data = response as List<dynamic>;

      if (data.isEmpty) return;

      await _db.batch((batch) {
        for (var txData in data) {
          final txId = txData['id'];
          
          // Insert Header
          batch.insert(_db.transactions, TransactionsCompanion.insert(
            id: txId,
            storeId: txData['store_id'],
            tenantId: txData['tenant_id'],
            subtotal: (txData['subtotal'] as num).toDouble(),
            taxAmount: (txData['tax_amount'] as num).toDouble(),
            totalAmount: (txData['total_amount'] as num).toDouble(),
            timestamp: DateTime.parse(txData['timestamp']),
            createdAt: Value(DateTime.parse(txData['created_at'] ?? txData['timestamp'])),
            updatedAt: Value(DateTime.parse(txData['updated_at'] ?? txData['timestamp'])),
            isDirty: const Value(false),
            syncStatus: const Value('synced'),
            lastSyncedAt: Value(DateTime.now()),
          ));

          // Insert Items
          final items = txData['transaction_items'] as List<dynamic>;
          for (var itemData in items) {
            batch.insert(_db.transactionItems, TransactionItemsCompanion.insert(
              transactionId: txId,
              productId: itemData['product_id'],
              productName: itemData['product_name'],
              quantity: (itemData['quantity'] as num).toDouble(),
              unitPrice: (itemData['unit_price'] as num).toDouble(),
              taxAmount: (itemData['tax_amount'] as num).toDouble(),
            ));
          }
        }
      });

      debugPrint('Cloud Recovery: Restored ${data.length} transactions.');

    } catch (e) {
      debugPrint('Cloud Recovery Error: $e');
      // Fail silently, we are offline or something is wrong.
    }
  }
}
