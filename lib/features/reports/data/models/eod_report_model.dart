import 'package:grocery/core/localization/mmk_rounding.dart';

/// End-of-Day financial reconciliation snapshot for one shift/store.
///
/// All monetary fields are in Myanmar Kyat (MMK) stored as [double].
/// The [bankTransferReady] field is rounded to the nearest 100 Kyat using
/// [roundToNearest100] to match cloud-side EOD aggregation parity logic.
class EodReportModel {
  EodReportModel({
    required this.closureId,
    required this.storeId,
    required this.tenantId,
    required this.closedAt,
    required this.totalSales,
    required this.taxCollected,
    required this.cashExpected,
    required this.cashActual,
    required this.discrepancy,
    required this.roundingAdjustment,
    this.syncStatusAtClosure,
    this.operatorNotes,
  });

  /// Unique ID for this closure record (UUID).
  final String closureId;

  /// Store this closure belongs to.
  final String storeId;

  /// Tenant this closure belongs to.
  final String tenantId;

  /// Timestamp when the register was officially closed.
  final DateTime closedAt;

  /// Sum of all transaction totals for the shift (5-Kyat rounded by POS).
  final double totalSales;

  /// Total tax collected across all transactions.
  final double taxCollected;

  /// Expected cash in drawer: [totalSales] after adjustments.
  final double cashExpected;

  /// Physical cash counted by the operator.
  final double cashActual;

  /// [cashActual] − [cashExpected]. Positive = surplus, negative = shortage.
  final double discrepancy;

  /// The raw 5-Kyat rounding deduction applied to individual transactions
  /// (accumulated difference between raw amounts and rounded POS totals).
  final double roundingAdjustment;

  /// The sync status label at the moment of closure (e.g. "synced", "pending").
  /// Recorded for audit purposes.
  final String? syncStatusAtClosure;

  /// Optional operator remarks entered during the wizard.
  final String? operatorNotes;

  // ── Computed fields ─────────────────────────────────────────────────────────

  /// Net cash position: [cashActual] − [roundingAdjustment].
  double get netCash => cashActual - roundingAdjustment;

  /// Cash ready for bank transfer, rounded to the nearest 100 Kyat for
  /// cloud-side EOD aggregation parity. Uses [roundMm100] extension.
  ///
  /// Example: netCash = 156,750 → bankTransferReady = 156,800
  int get bankTransferReady => netCash.roundMm100;

  /// `true` when the physical count matches expectations within ±50 Kyat.
  bool get isBalanced => discrepancy.abs() <= 50.0;

  // ── Factory constructors ─────────────────────────────────────────────────────

  /// Builds an [EodReportModel] from raw shift data.
  ///
  /// [totalSalesRaw] is the unrounded sum — this constructor derives
  /// [roundingAdjustment] automatically via [roundMm5Sum].
  factory EodReportModel.fromShiftData({
    required String closureId,
    required String storeId,
    required String tenantId,
    required DateTime closedAt,
    required List<double> rawTransactionAmounts,
    required double taxCollected,
    required double cashActual,
    String? syncStatusAtClosure,
    String? operatorNotes,
  }) {
    // Sum of raw (un-rounded) amounts.
    final rawTotal =
        rawTransactionAmounts.fold<double>(0.0, (sum, a) => sum + a);

    // Sum of 5-Kyat rounded amounts (what the POS actually charged).
    final roundedTotal = rawTransactionAmounts
        .fold<int>(0, (sum, a) => sum + a.roundMm)
        .toDouble();

    // Accumulate the total rounding deduction for the shift.
    final roundingAdj = rawTotal - roundedTotal;

    final cashExpected = roundedTotal;
    final discrepancy = cashActual - cashExpected;

    return EodReportModel(
      closureId: closureId,
      storeId: storeId,
      tenantId: tenantId,
      closedAt: closedAt,
      totalSales: roundedTotal,
      taxCollected: taxCollected,
      cashExpected: cashExpected,
      cashActual: cashActual,
      discrepancy: discrepancy,
      roundingAdjustment: roundingAdj,
      syncStatusAtClosure: syncStatusAtClosure,
      operatorNotes: operatorNotes,
    );
  }

  // ── Serialization ────────────────────────────────────────────────────────────

  factory EodReportModel.fromJson(Map<String, dynamic> json) => EodReportModel(
        closureId: json['closure_id'] as String,
        storeId: json['store_id'] as String,
        tenantId: json['tenant_id'] as String,
        closedAt: DateTime.parse(json['closed_at'] as String),
        totalSales: (json['total_sales'] as num).toDouble(),
        taxCollected: (json['tax_collected'] as num).toDouble(),
        cashExpected: (json['cash_expected'] as num).toDouble(),
        cashActual: (json['cash_actual'] as num).toDouble(),
        discrepancy: (json['discrepancy'] as num).toDouble(),
        roundingAdjustment: (json['rounding_adjustment'] as num).toDouble(),
        syncStatusAtClosure: json['sync_status_at_closure'] as String?,
        operatorNotes: json['operator_notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'closure_id': closureId,
        'store_id': storeId,
        'tenant_id': tenantId,
        'closed_at': closedAt.toUtc().toIso8601String(),
        'total_sales': totalSales,
        'tax_collected': taxCollected,
        'cash_expected': cashExpected,
        'cash_actual': cashActual,
        'discrepancy': discrepancy,
        'rounding_adjustment': roundingAdjustment,
        'bank_transfer_ready': bankTransferReady,
        'sync_status_at_closure': syncStatusAtClosure,
        'operator_notes': operatorNotes,
      };

  @override
  String toString() =>
      'EodReportModel(closureId: $closureId, totalSales: $totalSales, '
      'discrepancy: $discrepancy, bankTransferReady: $bankTransferReady, '
      'isBalanced: $isBalanced)';
}
