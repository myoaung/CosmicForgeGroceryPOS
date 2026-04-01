import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:grocery/core/database/local_database.dart';

void main() {
  test('schema version and indices present', () async {
    final db = LocalDatabase.forTesting(NativeDatabase.memory());
    expect(db.schemaVersion, 6);

    final indexRows = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE '%_idx'"
    ).get();
    final names = indexRows.map((r) => r.read<String>('name')).toSet();

    expect(names.contains('products_updated_at_idx'), true);
    expect(names.contains('transactions_updated_at_idx'), true);
    expect(names.contains('cart_items_updated_at_idx'), true);
    expect(names.contains('transaction_items_updated_at_idx'), true);
    expect(names.contains('sync_queue_status_idx'), true);

    final integrity = await db.customSelect('PRAGMA integrity_check').getSingle();
    expect(integrity.read<String>('integrity_check').toLowerCase(), 'ok');

    await db.close();
  });
}
