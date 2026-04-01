
/// Standard Myanmar Currency Rounding Logic
///
/// In Myanmar physical retail, 1 Kyat notes are obsolete.
/// Transactions are rounded to the nearest 5 or 10 Kyat at the POS terminal.
/// Cloud-side aggregation reports additionally use 50/100 Kyat rounding for
/// daily summary totals and transfer amounts.
///
/// ## Nearest-5 Examples (POS checkout)
/// * 1231 → 1230
/// * 1233 → 1235
/// * 1238 → 1240
///
/// ## Nearest-50 Examples (shift subtotals / float handover)
/// * 1220 → 1200
/// * 1225 → 1250
/// * 1260 → 1250
/// * 1275 → 1300
///
/// ## Nearest-100 Examples (daily/EOD cloud aggregation)
/// * 1249 → 1200
/// * 1250 → 1300
/// * 1350 → 1400

// ── 5-Kyat rounding ───────────────────────────────────────────────────────────

/// Rounds [amount] to the nearest 5 Kyat.
///
/// Used for every individual POS checkout transaction.
int roundToNearest5(double amount) => (amount / 5.0).round() * 5;

// ── 50-Kyat rounding ──────────────────────────────────────────────────────────

/// Rounds [amount] to the nearest 50 Kyat.
///
/// Used for shift subtotals and cash-float handover slips where individual
/// Kyat precision below 50 is impractical.
int roundToNearest50(double amount) => (amount / 50.0).round() * 50;

// ── 100-Kyat rounding ─────────────────────────────────────────────────────────

/// Rounds [amount] to the nearest 100 Kyat.
///
/// Used in cloud-side daily EOD aggregation and bank transfer amounts.
/// Local POS totals are rounded to this level before being compared against
/// the cloud-side summary to verify parity.
int roundToNearest100(double amount) => (amount / 100.0).round() * 100;

// ── Extensions ────────────────────────────────────────────────────────────────

/// Convenience extensions on [double] for each rounding granularity.
extension MmkRoundingDouble on double {
  /// Nearest 5 Kyat — standard POS checkout rounding.
  int get roundMm => roundToNearest5(this);

  /// Nearest 50 Kyat — shift subtotal / float handover rounding.
  int get roundMm50 => roundToNearest50(this);

  /// Nearest 100 Kyat — cloud EOD aggregation rounding.
  int get roundMm100 => roundToNearest100(this);
}

/// Convenience extensions on [int] for each rounding granularity.
extension MmkRoundingInt on int {
  /// Nearest 5 Kyat — standard POS checkout rounding.
  int get roundMm => roundToNearest5(toDouble());

  /// Nearest 50 Kyat — shift subtotal / float handover rounding.
  int get roundMm50 => roundToNearest50(toDouble());

  /// Nearest 100 Kyat — cloud EOD aggregation rounding.
  int get roundMm100 => roundToNearest100(toDouble());
}
