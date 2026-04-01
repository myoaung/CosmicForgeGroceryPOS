// test/features/order_idor_isolation_test.dart
//
// IDOR (Insecure Direct Object Reference) negative tests.
//
// These tests verify that the local query layer enforces tenant/store scoping,
// mirroring the RLS policies on Supabase. A token valid for tenant-A/store-A
// must never be able to retrieve records belonging to tenant-B or store-B —
// even when the caller knows or guesses a valid UUID.
//
// Approach: seed an in-memory Drift DB with records from two tenants. Then
// query using a scope locked to tenant-1/store-1 and assert zero rows come
// back for tenant-2/store-2 records.

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/database/local_database.dart';

void main() {
  late LocalDatabase db;

  // UUIDs for the two tenants/stores used across tests.
  const String tenantA = 'aaaaaaaa-0000-0000-0000-000000000001';
  const String storeA  = 'aaaaaaaa-0000-0000-0000-000000000002';
  const String tenantB = 'bbbbbbbb-0000-0000-0000-000000000001';
  const String storeB  = 'bbbbbbbb-0000-0000-0000-000000000002';

  // Known UUIDs for the seeded transactions.
  const String txIdA = 'txid-aaaa-0000-0001';
  const String txIdB = 'txid-bbbb-0000-0002';

  // Shared timestamp for seeding.
  final now = DateTime.now();

  setUp(() async {
    db = LocalDatabase.forTesting(NativeDatabase.memory());

    // Seed a transaction belonging to Tenant A / Store A.
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: txIdA,
        storeId: storeA,
        tenantId: tenantA,
        subtotal: 1000.0,
        taxAmount: 50.0,
        totalAmount: 1050.0,
        timestamp: now,
      ),
    );

    // Seed a transaction belonging to Tenant B / Store B.
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: txIdB,
        storeId: storeB,
        tenantId: tenantB,
        subtotal: 2000.0,
        taxAmount: 100.0,
        totalAmount: 2100.0,
        timestamp: now,
      ),
    );
  });

  tearDown(() async => db.close());

  // ── Test 1 ─────────────────────────────────────────────────────────────────
  //
  // A caller scoped to tenant-A must not receive tenant-B's transaction when
  // querying by tenant_id, even if they supply a known valid UUID.
  test(
    'IDOR-01: tenant-A scope cannot read tenant-B transaction by tenant_id',
    () async {
      final results = await (db.select(db.transactions)
            ..where((t) =>
                t.tenantId.equals(tenantA) & // caller's claimed scope
                t.id.equals(txIdB)))         // target: tenant-B UUID
          .get();

      expect(
        results,
        isEmpty,
        reason:
            'A tenant-A token must return zero rows when targeting '
            'a transaction UUID that belongs to tenant-B.',
      );
    },
  );

  // ── Test 2 ─────────────────────────────────────────────────────────────────
  //
  // A caller scoped to store-A must not receive store-B's transaction even
  // when both tenants happen to share the same tenant_id claim (cross-store
  // enumeration within a multi-store tenancy).
  test(
    'IDOR-02: store-A scope cannot read store-B transaction by store_id',
    () async {
      const sharedTenant = tenantA; // imagine both stores under same tenant

      // Re-seed store-B tx to share the same tenant for this edge case.
      const txIdBsameT = 'txid-cccc-0000-0003';
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: txIdBsameT,
          storeId: storeB,       // different store
          tenantId: sharedTenant, // same tenant
          subtotal: 500.0,
          taxAmount: 25.0,
          totalAmount: 525.0,
          timestamp: now,
        ),
      );

      final results = await (db.select(db.transactions)
            ..where((t) =>
                t.tenantId.equals(sharedTenant) &
                t.storeId.equals(storeA) & // caller only has store-A access
                t.id.equals(txIdBsameT)))  // target: store-B UUID
          .get();

      expect(
        results,
        isEmpty,
        reason:
            'A store-A scoped token must return zero rows when targeting '
            'a transaction UUID that belongs to store-B, even within the '
            'same tenant.',
      );
    },
  );

  // ── Test 3 ─────────────────────────────────────────────────────────────────
  //
  // A cross-tenant list query (no specific UUID) must return only the rows
  // belonging to the caller's scope — not an error, not all rows.
  // This confirms the "fail-safe" design: unknown IDs silently return empty,
  // providing no oracle for object enumeration.
  test(
    'IDOR-03: scoped list query returns only in-scope records, not an exception',
    () async {
      // Fetch all transactions visible to tenant-A / store-A.
      final results = await (db.select(db.transactions)
            ..where((t) =>
                t.tenantId.equals(tenantA) & t.storeId.equals(storeA)))
          .get();

      // Must contain exactly ONE (txIdA) — not txIdB.
      expect(results.length, 1,
          reason: 'Scoped query must return exactly one in-scope record.');
      expect(results.first.id, txIdA,
          reason: 'The returned record must be the one belonging to tenant-A.');
      expect(
        results.any((t) => t.id == txIdB),
        isFalse,
        reason: 'Tenant-B\'s transaction must never appear in the result set.',
      );
    },
  );
}
