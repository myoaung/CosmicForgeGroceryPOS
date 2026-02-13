
/// Standard Myanmar Currency Rounding Logic
///
/// In Myanmar physical retail, 1 Kyat notes are obsolete.
/// Transactions are rounded to the nearest 5 or 10 Kyat.
///
/// Examples:
/// 1231 -> 1230
/// 1232 -> 1230
/// 1233 -> 1235
/// 1234 -> 1235
/// 1236 -> 1235
/// 1237 -> 1235
/// 1238 -> 1240
/// 1239 -> 1240
int roundToNearest5(double amount) {
  return (amount / 5.0).round() * 5;
}

/// Extension for easy usage on double and int
extension MmkRoundingDouble on double {
  int get roundMm => roundToNearest5(this);
}

extension MmkRoundingInt on int {
  int get roundMm => roundToNearest5(this.toDouble());
}
