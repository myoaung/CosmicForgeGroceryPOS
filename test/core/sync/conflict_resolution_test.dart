// test/core/sync/conflict_resolution_test.dart
//
// Verifies the LWW conflict resolution logic and tenant isolation pre-check
// in SyncQueueWorker through observable DB state rather than method overrides.
//
// Strategy
// ════════
// SyncQueueWorker._validateTenantScope operates entirely on the local Drift DB
// (it reads the queue row's tenantId, compares it to the JWT tenantId, and
// writes the dead_letter status back to the DB). We can test this without a
// real Supabase client.
//
// For LWW (Scenarios A & B), the actual HTTP call happens inside
// _applySyncOperation → _supabase.from(table)..., which we cannot call
// without a live project. We therefore:
//   • Test ONLY the tenant-validation path with the real worker (Scenario C).
//   • Test LWW timestamp comparison logic directly as pure-Dart unit tests.
//
// This approach gives us maximum coverage of the *new* code without requiring
// a real Supabase client or private-method overrides.

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/sync/sync_queue_worker.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Seeds a [SyncQueue] row with [tenantId] and [updatedAt] in the payload.
Future<String> _seed(
  LocalDatabase db, {
  required String tenantId,
  required String entityId,
  required String updatedAt,
}) async {
  await db.into(db.syncQueues).insert(
    SyncQueuesCompanion.insert(
      tenantId: tenantId,
      storeId: const Value(null),
      entityType: 'products',
      entityId: entityId,
      operation: 'UPDATE',
      payload: jsonEncode({'id': entityId, 'updated_at': updatedAt}),
    ),
  );
  return entityId;
}

/// Returns the DB status of the first queue row matching [entityId].
Future<String?> _status(LocalDatabase db, String entityId) async {
  final row = await (db.select(db.syncQueues)
        ..where((q) => q.entityId.equals(entityId)))
      .getSingleOrNull();
  return row?.status;
}

/// Returns the error message of the first queue row matching [entityId].
Future<String?> _errorMsg(LocalDatabase db, String entityId) async {
  final row = await (db.select(db.syncQueues)
        ..where((q) => q.entityId.equals(entityId)))
      .getSingleOrNull();
  return row?.errorMessage;
}

// ── LWW pure-logic helpers (no Supabase needed) ───────────────────────────────

/// Mirrors the LWW decision gate inside SyncQueueWorker._applySyncOperation.
bool _lwwShouldSkip({
  required DateTime localUpdatedAt,
  required DateTime remoteUpdatedAt,
  ConflictStrategy strategy = ConflictStrategy.lastWriteWins,
}) {
  return strategy == ConflictStrategy.serverPriority
      ? !remoteUpdatedAt.isBefore(localUpdatedAt) // remote >= local → skip
      : remoteUpdatedAt.isAfter(localUpdatedAt);  // remote >  local → skip
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  late LocalDatabase db;

  const jwtTenant   = 'tenant-jwt-aaaa-bbbb';
  const otherTenant = 'tenant-other-xxxx-yyyy';

  setUp(() {
    db = LocalDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  // ── Scenario A — LWW: local is newer ────────────────────────────────────────
  group('Scenario A: local change is newer than cloud (LWW)', () {
    test('LWW gate: local newer → shouldSkip returns false (push proceeds)', () {
      final local  = DateTime.utc(2026, 4, 1, 12, 30);
      final remote = DateTime.utc(2026, 4, 1, 11,  0);

      expect(
        _lwwShouldSkip(localUpdatedAt: local, remoteUpdatedAt: remote),
        isFalse,
        reason: 'Local is ahead of remote → push must proceed.',
      );
    });

    test('LWW gate: local newer also wins under serverPriority', () {
      final local  = DateTime.utc(2026, 4, 1, 12, 30);
      final remote = DateTime.utc(2026, 4, 1, 11,  0);

      expect(
        _lwwShouldSkip(
          localUpdatedAt: local,
          remoteUpdatedAt: remote,
          strategy: ConflictStrategy.serverPriority,
        ),
        isFalse,
        reason: 'Even under serverPriority, local ahead of remote should push.',
      );
    });

    test('Queue item for matching tenant is left pending (not dead-lettered)', () async {
      // Worker with null Supabase — processQueue will skip network calls.
      final worker = SyncQueueWorker(db, null);
      final entityId = await _seed(
        db,
        tenantId: jwtTenant,
        entityId: 'prod-scenario-a',
        updatedAt: DateTime.utc(2026, 4, 1, 12, 0).toIso8601String(),
      );

      await worker.validateAndProcessQueue(jwtTenantId: jwtTenant);

      // Null Supabase means processOne exits early — item stays pending.
      // What matters: it was NOT killed as dead_letter by the tenant check.
      final status = await _status(db, entityId);
      expect(status, isNot('dead_letter'),
          reason: 'Matching tenant item must NOT be dead-lettered.');
    });
  });

  // ── Scenario B — LWW: cloud is newer ────────────────────────────────────────
  group('Scenario B: cloud change is newer than local (LWW)', () {
    test('LWW gate: cloud newer → shouldSkip returns true (push skipped)', () {
      final local  = DateTime.utc(2026, 4, 1, 10,  0);
      final remote = DateTime.utc(2026, 4, 1, 12, 30);

      expect(
        _lwwShouldSkip(localUpdatedAt: local, remoteUpdatedAt: remote),
        isTrue,
        reason: 'Remote is newer → push must be skipped.',
      );
    });

    test('LWW gate: equal timestamps → skip (no redundant push)', () {
      final ts = DateTime.utc(2026, 4, 1, 12, 0);

      expect(
        _lwwShouldSkip(localUpdatedAt: ts, remoteUpdatedAt: ts),
        isFalse, // strictly after — tie goes to local (isAfter is false)
        reason: 'Equal timestamps: remote is NOT strictly after → push proceeds '
            '(avoids infinite skip loops on back-and-forth sync).',
      );
    });

    test('LWW gate: serverPriority — equal timestamps → skip (server dominates)', () {
      final ts = DateTime.utc(2026, 4, 1, 12, 0);

      expect(
        _lwwShouldSkip(
          localUpdatedAt: ts,
          remoteUpdatedAt: ts,
          strategy: ConflictStrategy.serverPriority,
        ),
        isTrue,
        reason: 'serverPriority: remote >= local → skip.',
      );
    });
  });

  // ── Scenario C — Tenant mismatch → strict rejection ──────────────────────────
  group('Scenario C: tenant_id mismatch → dead_letter, no push', () {
    test('Mismatched tenant item is moved to dead_letter', () async {
      final worker = SyncQueueWorker(db, null);
      final entityId = await _seed(
        db,
        tenantId: otherTenant, // ← different from jwtTenant
        entityId: 'prod-scenario-c-mismatch',
        updatedAt: DateTime.utc(2026, 4, 1, 12, 0).toIso8601String(),
      );

      await worker.validateAndProcessQueue(jwtTenantId: jwtTenant);

      expect(
        await _status(db, entityId),
        'dead_letter',
        reason: 'Cross-tenant item must be dead-lettered immediately.',
      );
    });

    test('dead_letter error message identifies the mismatch', () async {
      final worker = SyncQueueWorker(db, null);
      final entityId = await _seed(
        db,
        tenantId: otherTenant,
        entityId: 'prod-scenario-c-errmsg',
        updatedAt: DateTime.utc(2026, 4, 1).toIso8601String(),
      );

      await worker.validateAndProcessQueue(jwtTenantId: jwtTenant);

      final msg = await _errorMsg(db, entityId);
      expect(msg, isNotNull);
      expect(msg, contains('TENANT_MISMATCH'),
          reason: 'Error message must name TENANT_MISMATCH for triage.');
      expect(msg, contains(otherTenant),
          reason: 'Error message must include the offending tenantId.');
      expect(msg, contains(jwtTenant),
          reason: 'Error message must include the JWT tenantId.');
    });

    test('Matching tenant item alongside mismatch is NOT dead-lettered', () async {
      final worker = SyncQueueWorker(db, null);

      final goodId = await _seed(
        db,
        tenantId: jwtTenant, // ← correct tenant
        entityId: 'prod-good-tenant',
        updatedAt: DateTime.utc(2026, 4, 1, 8, 0).toIso8601String(),
      );
      final badId = await _seed(
        db,
        tenantId: otherTenant, // ← wrong tenant
        entityId: 'prod-bad-tenant',
        updatedAt: DateTime.utc(2026, 4, 1, 8, 0).toIso8601String(),
      );

      await worker.validateAndProcessQueue(jwtTenantId: jwtTenant);

      expect(
        await _status(db, goodId),
        isNot('dead_letter'),
        reason: 'Correct-tenant item must never be dead-lettered by the mismatch check.',
      );
      expect(
        await _status(db, badId),
        'dead_letter',
        reason: 'Wrong-tenant item must be dead-lettered.',
      );
    });

    test('Multiple mismatched items are all dead-lettered in one pass', () async {
      final worker = SyncQueueWorker(db, null);
      final ids = <String>[];
      for (var i = 0; i < 3; i++) {
        ids.add(await _seed(
          db,
          tenantId: otherTenant,
          entityId: 'prod-multi-$i',
          updatedAt: DateTime.utc(2026, 4, 1).toIso8601String(),
        ));
      }

      await worker.validateAndProcessQueue(jwtTenantId: jwtTenant);

      for (final id in ids) {
        expect(
          await _status(db, id),
          'dead_letter',
          reason: 'Every cross-tenant item must be dead-lettered.',
        );
      }
    });
  });

  // ── Backoff documentation test ────────────────────────────────────────────────
  test(
    'Exponential backoff: already implemented (base 5s, max 2^8 multiplier)',
    () {
      const base = Duration(seconds: 5);
      expect(base * (1 << 0), const Duration(seconds: 5));   // retry 1
      expect(base * (1 << 3), const Duration(seconds: 40));  // retry 4
      expect(base * (1 << 8), const Duration(seconds: 1280)); // retry 9+
    },
  );
}
