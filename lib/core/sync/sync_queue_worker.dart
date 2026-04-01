import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/local_database.dart';
import 'package:grocery/core/services/observability_service.dart';

enum SyncOperation { insert, update, delete }
enum SyncQueueStatus { pending, processing, success, failed, deadLetter }
enum ConflictStrategy { lastWriteWins, serverPriority, manualMerge }

class SyncQueueWorker {
  SyncQueueWorker(this._db, this._supabase, {ObservabilityService obs = const ObservabilityService()}) : _obs = obs;

  final LocalDatabase _db;
  final SupabaseClient? _supabase;
  final ObservabilityService _obs;

  static const int _maxRetries = 6;
  static const Duration _baseRetryDelay = Duration(seconds: 5);

  Timer? _timer;

  void startScheduledProcessing({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => processQueue());
  }

  void stopScheduledProcessing() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> enqueue({
    required String tenantId,
    required String? storeId,
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
    int version = 1,
    String? deviceId,
  }) async {
    // Enterprise Action Directive: Sync Queue Memory Protection
    // Enforce max_queue_limit = 10000 to prevent OOM on massive offline loads.
    final countQuery = await _db.customSelect('SELECT COUNT(*) as c FROM sync_queues WHERE status IN (?, ?)', variables: [drift.Variable.withString('pending'), drift.Variable.withString('failed')]).getSingle();
    final queueCount = countQuery.data['c'] as int;
    
    if (queueCount >= 10000) {
      _obs.captureSentryEvent(
        'sync_queue_overflow_fatal',
        metadata: {'queue_size': queueCount, 'entity_type': entityType},
        level: 'fatal',
      );
      throw StateError('SYNC_QUEUE_OVERFLOW: Maximum offline queue limit reached (10000 items). Please reconnect to the internet to process the queue before continuing operations.');
    }

    await _db.into(_db.syncQueues).insert(
          SyncQueuesCompanion.insert(
            tenantId: tenantId,
            storeId: drift.Value(storeId),
            entityType: entityType,
            entityId: entityId,
            operation: operation.name.toUpperCase(),
            payload: jsonEncode(payload),
            version: drift.Value(version),
            deviceId: drift.Value(deviceId),
          ),
        );
  }

  Future<void> processQueue({
    int batchSize = 50,
    ConflictStrategy conflictStrategy = ConflictStrategy.lastWriteWins,
  }) async {
    if (_supabase == null) {
      debugPrint('SyncQueueWorker: Supabase unavailable. Queue processing skipped.');
      return;
    }

    final now = DateTime.now();
    final candidates = await (_db.select(_db.syncQueues)
          ..where((q) =>
              (q.status.equals(SyncQueueStatus.pending.name) |
                  q.status.equals(SyncQueueStatus.failed.name)) &
              (q.nextAttemptAt.isNull() | q.nextAttemptAt.isSmallerOrEqualValue(now)))
          ..orderBy([(q) => drift.OrderingTerm(expression: q.createdAt)])
          ..limit(batchSize))
        .get();

    _obs.incrementMetric('sync.queue_length', value: candidates.length);

    for (final item in candidates) {
      await _processOne(item, conflictStrategy);
    }
  }

  /// Tenant-scoped queue processing — validates every item's [tenantId]
  /// against the live JWT claim's [jwtTenantId] before pushing to the edge.
  ///
  /// Any queue item whose [tenantId] does not match [jwtTenantId] is
  /// immediately moved to `dead_letter` with error `TENANT_MISMATCH` and
  /// will never touch the Supabase edge. This prevents cross-tenant data leaks
  /// caused by stale queue items accumulated during a user-switch event.
  ///
  /// **Phase 1 (always runs):** Loads all pending/failed items and dead-letters
  /// any whose tenantId mismatches the JWT. This phase runs even offline so
  /// stale cross-tenant queue rows are always cleaned up.
  ///
  /// **Phase 2 (requires Supabase):** Pushes the remaining in-scope items.
  Future<void> validateAndProcessQueue({
    required String jwtTenantId,
    int batchSize = 50,
    ConflictStrategy conflictStrategy = ConflictStrategy.lastWriteWins,
  }) async {
    final now = DateTime.now();
    final candidates = await (_db.select(_db.syncQueues)
          ..where((q) =>
              (q.status.equals(SyncQueueStatus.pending.name) |
                  q.status.equals(SyncQueueStatus.failed.name)) &
              (q.nextAttemptAt.isNull() | q.nextAttemptAt.isSmallerOrEqualValue(now)))
          ..orderBy([(q) => drift.OrderingTerm(expression: q.createdAt)])
          ..limit(batchSize))
        .get();

    _obs.incrementMetric('sync.queue_length', value: candidates.length);

    // ── Phase 1: Tenant isolation (always runs, no Supabase needed) ───────────
    final inScope = <SyncQueue>[];
    for (final item in candidates) {
      final mismatch = await _validateTenantScope(item, jwtTenantId);
      if (!mismatch) inScope.add(item);
    }

    // ── Phase 2: Push in-scope items (requires Supabase) ─────────────────────
    if (_supabase == null) {
      debugPrint('SyncQueueWorker.validateAndProcessQueue: '
          'Supabase unavailable — tenant validation done, push skipped.');
      return;
    }

    for (final item in inScope) {
      await _processOne(item, conflictStrategy);
    }
  }

  /// Returns `true` (and dead-letters the item) if [item.tenantId] does not
  /// match [jwtTenantId]. Returns `false` when the item is safe to process.
  Future<bool> _validateTenantScope(
    SyncQueue item,
    String jwtTenantId,
  ) async {
    if (item.tenantId == jwtTenantId) return false;

    // Tenant mismatch — move directly to dead_letter.
    await (_db.update(_db.syncQueues)..where((q) => q.id.equals(item.id))).write(
      SyncQueuesCompanion(
        status: const drift.Value('dead_letter'),
        errorMessage: drift.Value(
          'TENANT_MISMATCH: queue.tenantId=${item.tenantId} '
          '!= jwt.tenantId=$jwtTenantId',
        ),
      ),
    );

    _obs.captureSentryEvent(
      'sync_tenant_mismatch',
      metadata: {
        'item_id': item.id,
        'queue_tenant': item.tenantId,
        'jwt_tenant': jwtTenantId,
        'entity_type': item.entityType,
        'entity_id': item.entityId,
      },
      level: 'error',
    );
    _obs.incrementMetric('sync.tenant_mismatch');
    debugPrint(
      'SyncQueueWorker: TENANT_MISMATCH item=${item.id} '
      'queue=${item.tenantId} jwt=$jwtTenantId → dead_letter',
    );
    return true;
  }

  Future<void> _processOne(
    SyncQueue item,
    ConflictStrategy conflictStrategy,
  ) async {
    final now = DateTime.now();

    await (_db.update(_db.syncQueues)..where((q) => q.id.equals(item.id))).write(
      SyncQueuesCompanion(
        status: const drift.Value('processing'),
        lastAttemptAt: drift.Value(now),
      ),
    );

    try {
      // OPERATION ORACLE RSK-01: Offload JSON deserialization to a separate Isolate 
      // preventing the 60fps UI thread from blocking during heavy backlogged queue parsing (10k items).
      final payloadStr = item.payload;
      final payload = await compute<String, Map<String, dynamic>>(
        (String p) => jsonDecode(p) as Map<String, dynamic>,
        payloadStr,
      );
      
      await _applySyncOperation(item.entityType, item.entityId, item.operation, payload, conflictStrategy);

      await (_db.update(_db.syncQueues)..where((q) => q.id.equals(item.id))).write(
        const SyncQueuesCompanion(
          status: drift.Value('success'),
          errorMessage: drift.Value(null),
        ),
      );
    } catch (e) {
      final String errorStr = e.toString();
      final bool isPermanentError = errorStr.contains('ConflictException') || 
                                    errorStr.contains('Validation') || 
                                    errorStr.contains('400');
                                    
      final int retries = isPermanentError ? _maxRetries : item.retryCount + 1;
      final bool isDeadLetter = retries >= _maxRetries;
      final Duration backoff = _baseRetryDelay * (1 << (retries - 1).clamp(0, 8));

      await (_db.update(_db.syncQueues)..where((q) => q.id.equals(item.id))).write(
        SyncQueuesCompanion(
          retryCount: drift.Value(retries),
          status: drift.Value(isDeadLetter ? 'dead_letter' : SyncQueueStatus.failed.name),
          nextAttemptAt: drift.Value(isDeadLetter ? null : DateTime.now().add(backoff)),
          errorMessage: drift.Value(e.toString()),
        ),
      );
      
      _obs.incrementMetric('sync.retry');
      if (isDeadLetter) {
        _obs.captureSentryEvent(
          'sync_queue_dead_letter',
          metadata: {
            'item_id': item.id,
            'entity_type': item.entityType,
            'error': e.toString(),
            'retry_count': retries,
          },
          level: 'error',
        );
      }
      debugPrint('SyncQueueWorker: failed item ${item.id}, retry=$retries, error=$e');
    }
  }

  Future<void> _applySyncOperation(
    String entityType,
    String entityId,
    String operation,
    Map<String, dynamic> payload,
    ConflictStrategy conflictStrategy,
  ) async {
    final table = _resolveTable(entityType);
    final op = operation.toUpperCase();

    if (op == 'DELETE') {
      await _supabase!.from(table).delete().eq('id', entityId);
      return;
    }

    if (conflictStrategy == ConflictStrategy.manualMerge) {
      throw StateError('manual_merge_required:$entityType:$entityId');
    }

    // ── Last-Write-Wins (LWW) via explicit updated_at comparison ─────────────
    //
    // For INSERT/UPDATE, we fetch the remote updated_at before deciding whether
    // to push. This makes the LWW decision deterministic on the client side and
    // avoids unnecessary upserts that could trigger Supabase trigger overhead.
    //
    // Resolution matrix:
    //   local  > remote → push local   (emit sync.lww.push)
    //   local  < remote → pull wins    (emit sync.lww.skip; no network write)
    //   local == remote → no-op        (emit sync.lww.skip)
    //   remote missing  → insert local (emit sync.lww.push; new record)
    //
    // serverPriority is treated as an alias for LWW where the remote timestamp
    // always wins when equal-or-newer.
    final localUpdatedAt = payload['updated_at'] != null
        ? DateTime.tryParse(payload['updated_at'].toString())
        : null;

    if (op != 'INSERT' || localUpdatedAt != null) {
      final remote = await _supabase!
          .from(table)
          .select('updated_at')
          .eq('id', entityId)
          .maybeSingle();

      if (remote != null && remote['updated_at'] != null) {
        final remoteUpdatedAt =
            DateTime.tryParse(remote['updated_at'].toString());

        if (remoteUpdatedAt != null && localUpdatedAt != null) {
          final serverNewer = conflictStrategy == ConflictStrategy.serverPriority
              ? !remoteUpdatedAt.isBefore(localUpdatedAt) // remote >= local
              : remoteUpdatedAt.isAfter(localUpdatedAt);  // remote > local

          if (serverNewer) {
            // Cloud wins — skip the push. Local record will be refreshed on
            // the next syncProducts / downstream pull cycle.
            _obs.incrementMetric('sync.lww.skip', labels: {
              'entity': entityType,
              'reason': 'server_newer',
            });
            debugPrint(
              'SyncQueueWorker LWW: skip $entityType/$entityId '
              '(remote=${remoteUpdatedAt.toIso8601String()} '
              '>= local=${localUpdatedAt.toIso8601String()})',
            );
            return;
          }
        }
      }
    }

    // Local is newer (or no remote record exists) — push to cloud.
    await _supabase!.from(table).upsert(payload, onConflict: 'id');
    _obs.incrementMetric('sync.lww.push', labels: {'entity': entityType});
  }

  String _resolveTable(String entityType) {
    switch (entityType) {
      case 'products':
        return 'products';
      case 'inventory':
        return 'inventory';
      case 'orders':
        return 'orders';
      case 'order_items':
        return 'order_items';
      case 'payments':
        return 'payments';
      case 'reports':
        return 'reports';
      case 'devices':
        return 'devices';
      case 'transactions':
        return 'transactions';
      case 'transaction_items':
        return 'transaction_items';
      default:
        throw ArgumentError('Unsupported entity type: $entityType');
    }
  }
}
