import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/localization/mmk_rounding.dart';

void main() {
  // ── 5-Kyat (POS Terminal Checkout) ──────────────────────────────────────────
  group('MMK 5-Kyat Rounding (POS checkout)', () {
    test('Rounds to nearest 5 Kyat', () {
      expect(roundToNearest5(1230.0), 1230);
      expect(roundToNearest5(1231.0), 1230);
      expect(roundToNearest5(1232.0), 1230);
      expect(roundToNearest5(1233.0), 1235);
      expect(roundToNearest5(1234.0), 1235);
      expect(roundToNearest5(1235.0), 1235);
      expect(roundToNearest5(1236.0), 1235);
      expect(roundToNearest5(1237.0), 1235);
      expect(roundToNearest5(1238.0), 1240);
      expect(roundToNearest5(1239.0), 1240);
    });

    test('double.roundMm extension works', () {
      expect(1234.0.roundMm, 1235);
      expect(1238.0.roundMm, 1240);
    });

    test('int.roundMm extension works', () {
      expect(1234.roundMm, 1235);
      expect(1238.roundMm, 1240);
    });
  });

  // ── 50-Kyat (Shift Subtotals / Cash Float Handover) ─────────────────────────
  group('MMK 50-Kyat Rounding (shift subtotals)', () {
    test('Rounds to nearest 50 Kyat', () {
      expect(roundToNearest50(1200.0), 1200);
      expect(roundToNearest50(1220.0), 1200); // 20 below 1250 midpoint
      expect(roundToNearest50(1225.0), 1250); // exact midpoint → up
      expect(roundToNearest50(1249.0), 1250);
      expect(roundToNearest50(1250.0), 1250);
      expect(roundToNearest50(1260.0), 1250); // 10 above 1250 → rounds to 1250
      expect(roundToNearest50(1275.0), 1300); // exact midpoint → up
      expect(roundToNearest50(1300.0), 1300);
    });

    test('double.roundMm50 extension works', () {
      expect(1220.0.roundMm50, 1200);
      expect(1275.0.roundMm50, 1300);
    });

    test('int.roundMm50 extension works', () {
      expect(1220.roundMm50, 1200);
      expect(1275.roundMm50, 1300);
    });

    test('50-Kyat and 5-Kyat are consistent on multiples of 50', () {
      // Any multiple of 50 should round to itself under both strategies.
      const values = [1000.0, 1050.0, 1100.0, 1500.0, 5000.0];
      for (final v in values) {
        expect(roundToNearest50(v), v.toInt(),
            reason: '$v is already a multiple of 50');
        expect(roundToNearest5(v), v.toInt(),
            reason: '$v is already a multiple of 5');
      }
    });
  });

  // ── 100-Kyat (Cloud EOD Aggregation) ────────────────────────────────────────
  group('MMK 100-Kyat Rounding (cloud EOD aggregation)', () {
    test('Rounds to nearest 100 Kyat', () {
      expect(roundToNearest100(1000.0), 1000);
      expect(roundToNearest100(1049.0), 1000); // below midpoint
      expect(roundToNearest100(1050.0), 1100); // exact midpoint → up
      expect(roundToNearest100(1099.0), 1100);
      expect(roundToNearest100(1100.0), 1100);
      expect(roundToNearest100(1150.0), 1200); // midpoint → up
      expect(roundToNearest100(1349.0), 1300);
      expect(roundToNearest100(1350.0), 1400); // midpoint → up
    });

    test('double.roundMm100 extension works', () {
      expect(1049.0.roundMm100, 1000);
      expect(1350.0.roundMm100, 1400);
    });

    test('int.roundMm100 extension works', () {
      expect(1049.roundMm100, 1000);
      expect(1350.roundMm100, 1400);
    });

    test('Cloud-vs-local parity: 5-Kyat total rounds consistently to 100', () {
      // Simulates a session where local 5-Kyat rounded totals are compared
      // against the cloud EOD 100-Kyat aggregated total.
      const localTransactions = [1233.0, 1476.0, 2891.0];
      final localSum = localTransactions
          .map(roundToNearest5)
          .fold<int>(0, (sum, v) => sum + v);
      // localSum = 1235 + 1475 + 2890 = 5600
      final cloudAggTotal = roundToNearest100(localSum.toDouble());
      expect(cloudAggTotal, 5600,
          reason: '5600 is already a multiple of 100; parity confirmed.');
    });
  });
}
