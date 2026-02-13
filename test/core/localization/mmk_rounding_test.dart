import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/localization/mmk_rounding.dart';

void main() {
  group('MMK Cash Rounding Logic', () {
    test('Rounds to nearest 5 Kyat', () {
      expect(roundToNearest5(1230.0), 1230);
      expect(roundToNearest5(1231.0), 1230); // 1 diff vs 4 diff
      expect(roundToNearest5(1232.0), 1230); // 2 diff vs 3 diff
      expect(roundToNearest5(1233.0), 1235); // 2 diff vs 3 diff
      expect(roundToNearest5(1234.0), 1235); // 1 diff vs 4 diff
      expect(roundToNearest5(1235.0), 1235);
      expect(roundToNearest5(1236.0), 1235);
      expect(roundToNearest5(1237.0), 1235);
      expect(roundToNearest5(1238.0), 1240);
      expect(roundToNearest5(1239.0), 1240);
    });

    test('Extension works on double', () {
      expect(1234.0.roundMm, 1235);
      expect(1238.0.roundMm, 1240);
    });

    test('Extension works on int', () {
      expect(1234.roundMm, 1235);
      expect(1238.roundMm, 1240);
    });
  });
}
