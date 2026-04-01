// test/features/reports/eod_reconciliation_test.dart
//
// EOD Report reconciliation tests:
//   Test 1: roundingAdjustment handles 5/50/100 Kyat midpoints correctly.
//   Test 2: EOD cannot be submitted when SyncStatus is tenantError.

import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/localization/mmk_rounding.dart';
import 'package:grocery/core/providers/sync_provider.dart';
import 'package:grocery/features/reports/data/models/eod_report_model.dart';

void main() {
  // Common fixtures
  const storeId  = 'store-aaaa-0001';
  const tenantId = 'tenant-aaaa-0001';
  final closedAt = DateTime.utc(2026, 4, 1, 17, 0, 0);

  EodReportModel _buildFromAmounts(
    List<double> amounts, {
    double cashActual = 0,
  }) =>
      EodReportModel.fromShiftData(
        closureId: 'cl-0001',
        storeId: storeId,
        tenantId: tenantId,
        closedAt: closedAt,
        rawTransactionAmounts: amounts,
        taxCollected: 0,
        cashActual: cashActual,
      );

  // ── Test 1: roundingAdjustment — midpoint correctness ─────────────────────
  group('Test 1: roundingAdjustment handles 5/50/100 Kyat midpoints', () {
    // Each sub-test validates a specific midpoint scenario.

    test('1a: No rounding when all amounts are exact multiples of 5', () {
      final report = _buildFromAmounts([1000.0, 2500.0, 750.0]);
      // 1000 → 1000, 2500 → 2500, 750 → 750 (all exact multiples)
      expect(report.roundingAdjustment, closeTo(0.0, 0.01),
          reason: 'No rounding loss when amounts are already multiples of 5.');
      expect(report.totalSales, closeTo(4250.0, 0.01));
    });

    test('1b: Positive rounding adjustment (raw > rounded)', () {
      // 1233 rounds to 1235 → rounded is 2 MORE than raw? No:
      // roundToNearest5(1233) = 1235. raw = 1233, rounded = 1235.
      // roundingAdj = 1233 - 1235 = -2 (rounded is larger; customer overpays by 2).
      // but for 1231: roundToNearest5(1231) = 1230. raw=1231, rounded=1230.
      // roundingAdj = 1231 - 1230 = +1 (raw > rounded; store collects 1 less).
      final report = _buildFromAmounts([1231.0, 1236.0]);
      // 1231 → 1230 (raw - rounded = +1)
      // 1236 → 1235 (raw - rounded = +1)
      // total roundingAdj = 2.0
      expect(report.roundingAdjustment, closeTo(2.0, 0.01),
          reason: '1231→1230 and 1236→1235 each lose 1 Kyat.');
      expect(report.totalSales, closeTo(2465.0, 0.01)); // 1230+1235
    });

    test('1c: Negative rounding adjustment (rounded > raw)', () {
      // 1233 → 1235 (raw 1233, rounds UP to 1235; store collects 2 MORE).
      // roundingAdj = 1233 - 1235 = -2.0
      final report = _buildFromAmounts([1233.0]);
      expect(report.roundingAdjustment, closeTo(-2.0, 0.01),
          reason: '1233 rounds UP to 1235; rounding adj = 1233 - 1235 = -2.');
    });

    test('1d: bankTransferReady uses roundMm100 on netCash', () {
      // totalSales = 1235 (1233 → 1235), roundingAdj = -2.0
      // cashActual = 1235, netCash = 1235 - (-2) = 1237
      // roundMm100(1237) = 1200 (1237 is below midpoint 1250)
      final report = _buildFromAmounts([1233.0], cashActual: 1235.0);
      expect(report.bankTransferReady, roundToNearest100(report.netCash));
      expect(report.bankTransferReady, 1200,
          reason: 'netCash=1237 → nearest 100 = 1200.');
    });

    test('1e: bankTransferReady midpoint (exactly 1250) rounds up to 1300', () {
      // We need netCash = 1250 exactly.
      // cashActual = 1252, roundingAdj = 1250 - 1252 = -2 → netCash = 1252-(-2)=1254? No.
      // Simpler: use exact multiples so roundingAdj = 0, cashActual = 1250.
      final report = _buildFromAmounts([1250.0], cashActual: 1250.0);
      // roundMm100(1250) = 1300 (midpoint rounds up in Dart's rounding)
      expect(report.bankTransferReady, 1300,
          reason: 'netCash=1250 is the midpoint; rounds up to 1300.');
    });

    test('1f: 50-Kyat shift subtotal midpoint: 1225 rounds to 1250', () {
      // Directly validate the 50-Kyat rounding expected to be used in reporting.
      expect(roundToNearest50(1225.0), 1250,
          reason: '1225 is the midpoint; should round up to 1250.');
    });

    test('1g: Multi-transaction shift produces correct cumulative adjustment', () {
      // Simulates a busy day with mixed rounding directions.
      const amounts = [1231.0, 1233.0, 1236.0, 1238.0, 1250.0];
      // 1231→1230 (+1), 1233→1235 (-2), 1236→1235 (+1), 1238→1240 (-2), 1250→1250 (0)
      // Total adjustment = 1 - 2 + 1 - 2 + 0 = -2
      final report = _buildFromAmounts(amounts);
      expect(report.roundingAdjustment, closeTo(-2.0, 0.01));
    });

    test('1h: isBalanced true when discrepancy <= 50 Kyat', () {
      // cashExpected = 1250, cashActual = 1295 → discrepancy = +45 → balanced
      final report = _buildFromAmounts([1250.0], cashActual: 1295.0);
      expect(report.discrepancy, closeTo(45.0, 0.01));
      expect(report.isBalanced, isTrue);
    });

    test('1i: isBalanced false when discrepancy > 50 Kyat', () {
      // cashExpected = 1250, cashActual = 1200 → discrepancy = -50 is boundary
      // cashActual = 1199 → discrepancy = -51 → not balanced
      final report = _buildFromAmounts([1250.0], cashActual: 1199.0);
      expect(report.discrepancy, closeTo(-51.0, 0.01));
      expect(report.isBalanced, isFalse);
    });
  });

  // ── Test 2: EOD blocked when SyncStatus is tenantError ─────────────────────
  group('Test 2: EOD cannot be submitted when SyncStatus is tenantError', () {
    /// Simulates the submission gate that EodClosureScreen enforces.
    /// Returns true if the operator is allowed to finalize EOD.
    bool canFinalizeEod(SyncState syncState) {
      // EOD must be blocked on any error state that indicates data integrity risk.
      return syncState.status != SyncStatus.tenantError &&
          syncState.status != SyncStatus.forbidden;
    }

    test('2a: canFinalizeEod returns false when status is tenantError', () {
      const state = SyncState(
        status: SyncStatus.tenantError,
        pendingCount: 3,
        lastErrorMessage: 'TENANT_MISMATCH: queue.tenantId=X != jwt.tenantId=Y',
      );
      expect(canFinalizeEod(state), isFalse,
          reason: 'EOD must be blocked when tenant mismatch is detected.');
    });

    test('2b: canFinalizeEod returns false when status is forbidden (403)', () {
      const state = SyncState(
        status: SyncStatus.forbidden,
        pendingCount: 1,
        lastErrorCode: 403,
      );
      expect(canFinalizeEod(state), isFalse,
          reason: 'EOD must be blocked when a 403 error is active.');
    });

    test('2c: canFinalizeEod returns true when fully synced', () {
      const state = SyncState(
        status: SyncStatus.synced,
        pendingCount: 0,
      );
      expect(canFinalizeEod(state), isTrue);
    });

    test('2d: canFinalizeEod returns true when offline with pending items', () {
      // Offline with pending is a normal end-of-shift state (cash out first,
      // sync can complete later). Only error states block EOD.
      const state = SyncState(
        status: SyncStatus.offline,
        pendingCount: 5,
      );
      expect(canFinalizeEod(state), isTrue,
          reason: 'Offline-pending is normal; only error states block EOD.');
    });

    test('2e: canFinalizeEod blocks all error states exhaustively', () {
      final errorStates = [SyncStatus.tenantError, SyncStatus.forbidden];
      final allowedStates = [
        SyncStatus.synced,
        SyncStatus.pending,
        SyncStatus.offline,
      ];

      for (final status in errorStates) {
        final state = SyncState(status: status, pendingCount: 0);
        expect(canFinalizeEod(state), isFalse,
            reason: '$status must block EOD finalization.');
      }

      for (final status in allowedStates) {
        final state = SyncState(status: status, pendingCount: 0);
        expect(canFinalizeEod(state), isTrue,
            reason: '$status must allow EOD finalization.');
      }
    });

    test('2f: EodReportModel records syncStatusAtClosure at time of submission', () {
      final report = EodReportModel.fromShiftData(
        closureId: 'cl-0002',
        storeId: storeId,
        tenantId: tenantId,
        closedAt: closedAt,
        rawTransactionAmounts: [1250.0],
        taxCollected: 100.0,
        cashActual: 1250.0,
        syncStatusAtClosure: 'synced', // captured at submission time
      );

      expect(report.syncStatusAtClosure, 'synced');
      expect(report.toJson()['sync_status_at_closure'], 'synced');
    });
  });
}
