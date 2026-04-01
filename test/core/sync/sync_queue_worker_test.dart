import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/sync/sync_queue_worker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late LocalDatabase db;

  setUp(() {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('enqueue writes pending sync queue item', () async {
    final worker = SyncQueueWorker(db, null);
    await worker.enqueue(
      tenantId: 'tenant-1',
      storeId: 'store-1',
      entityType: 'products',
      entityId: 'p1',
      operation: SyncOperation.insert,
      payload: const {'id': 'p1', 'name': 'Tea'},
      version: 3,
      deviceId: 'device-abc',
    );

    final rows = await db.select(db.syncQueues).get();
    expect(rows.length, 1);
    final first = rows.first;
    expect(first.status, SyncQueueStatus.pending.name);
    expect(first.retryCount, 0);
    expect(first.version, 3);
    expect(first.deviceId, 'device-abc');
  });

  test('failed remote sync increments retry_count and marks failed', () async {
    final fakeRemote = SupabaseClient('https://example.invalid', 'anon');
    final worker = SyncQueueWorker(db, fakeRemote);

    await worker.enqueue(
      tenantId: 'tenant-1',
      storeId: 'store-1',
      entityType: 'products',
      entityId: 'p1',
      operation: SyncOperation.insert,
      payload: const {
        'id': 'p1',
        'tenant_id': 'tenant-1',
        'store_id': 'store-1',
        'updated_at': '2026-03-08T00:00:00Z'
      },
    );

    await worker.processQueue();

    final row = await db.select(db.syncQueues).getSingle();
    expect(row.retryCount, 1);
    expect(row.status, SyncQueueStatus.failed.name);
    expect(row.nextAttemptAt, isNotNull);
  });
}
