import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/features/history/providers/history_provider.dart';

void main() {
  late LocalDatabase db;
  late HistoryNotifier historyNotifier;

  setUp(() async {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
    historyNotifier = HistoryNotifier(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('loadHistory fetches transactions sorted by date desc', () async {
    // Seed
    final now = DateTime.now();
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: 't1', 
        storeId: 's1', 
        tenantId: 'tn1', 
        subtotal: 100, 
        taxAmount: 0, 
        totalAmount: 100, 
        timestamp: now.subtract(const Duration(hours: 1))
      )
    );
    await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
            id: 't2',
            storeId: 's1',
            tenantId: 'tn1',
            subtotal: 200,
            taxAmount: 0,
            totalAmount: 200,
            timestamp: now
        )
    );

    await historyNotifier.loadHistory();
    
    final state = historyNotifier.state;
    expect(state.value!.length, 2);
    expect(state.value![0].transaction.id, 't2'); // t2 is newer
    expect(state.value![1].transaction.id, 't1');
  });
}
