import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:screenshot/screenshot.dart';
import 'package:image/image.dart' as img;
import '../../features/receipt/widgets/receipt_layout.dart';
import '../database/local_database.dart';
import '../../core/services/store_service.dart';
import 'observability_service.dart';

class ReceiptService {
  final BlueThermalPrinter _printer;
  final ScreenshotController _screenshotController = ScreenshotController();
  final ObservabilityService _obs = const ObservabilityService();

  ReceiptService({BlueThermalPrinter? printer})
      : _printer = printer ?? BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getBondedDevices() async {
    if (kIsWeb) return const [];
    return await _printer.getBondedDevices();
  }

  Future<bool> connect(BluetoothDevice device) async {
    if (kIsWeb) return false;
    try {
      if ((await _printer.isConnected) == true) {
        return true;
      }
      return await _printer.connect(device) ?? false;
    } catch (e) {
      _obs.recordEvent('printer_connection_error', metadata: {'error': e.toString()});
      return false;
    }
  }
  
  Future<void> disconnect() async {
    if (kIsWeb) return;
    if ((await _printer.isConnected) == true) {
      await _printer.disconnect();
    }
  }

  /// Prints a widget as a bitmap image to ensure font compatibility
  Future<void> printReceiptFromWidget(Widget widget, {required BluetoothDevice? device}) async {
    if (kIsWeb) {
      _obs.recordEvent('print_skipped_web');
      return;
    }
    if (device == null) {
      _obs.recordEvent('print_no_device_selected');
      return;
    }

    if ((await _printer.isConnected) != true) {
      final connected = await connect(device);
      if (!connected) {
        _obs.recordEvent('print_connection_failed');
        return;
      }
    }

    try {
      // 1. Capture Widget as Image (Uint8List)
      // Delay slightly to ensure widget is built if needed, though ScreenshotController usually handles it
      final Uint8List imageBytes = await _screenshotController.captureFromWidget(
        Container(
          width: 384, // Standard 58mm width approx in pixels (may need tuning)
          color: Colors.white,
          child: widget,
        ),
        delay: const Duration(milliseconds: 50),
      );

      // 2. Resize/Process Image for Printer (Optional but recommended)
      // BlueThermalPrinter might handle resizing, but resizing to width helps.
      // Assuming 58mm printer ~ 384 dots width.
      img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage != null) {
        // Resize to 384 width (standard 58mm printer width)
        img.Image resized = img.copyResize(decodedImage, width: 384);
        
        // Print
        await _printer.printImageBytes(Uint8List.fromList(img.encodePng(resized)));
        await _printer.paperCut();
      }
    } catch (e) {
      _obs.recordEvent('print_error', metadata: {'error': e.toString()});
    }
  }

  Future<void> printReceipt({
    required Transaction transaction,
    required List<TransactionItem> items,
    required String storeName,
    required BluetoothDevice? device,
    required StoreService storeService,
  }) async {
    if (kIsWeb) {
      _obs.recordEvent('print_skipped_web');
      return;
    }
    final receiptWidget = ReceiptLayout(
      transaction: transaction,
      items: items,
      storeName: storeName,
    );
    
    await printReceiptFromWidget(receiptWidget, device: device);
    
    // Audit Log
    await storeService.logAudit(
      actionType: 'PRINT_RECEIPT', 
      description: 'Printed receipt for Order #${transaction.id.substring(0, 8)}'
    );
  }

  // ── EOD Summary ─────────────────────────────────────────────────────────────

  /// Generates and prints an 80 mm thermal-printer-friendly EOD summary.
  ///
  /// The layout is intentionally text-heavy (no images) for maximum thermal
  /// compatibility. Width is capped to 48 characters — the standard 80 mm
  /// column count at 203 dpi.
  ///
  /// Includes the [syncStatusAtClosure] label from the [EodReportModel] so the
  /// printed receipt records the sync health at the moment of finalization.
  ///
  /// If [device] is null the method no-ops (safe to call on web/desktop).
  Future<void> generateEodSummary({
    required EodReportModel report,
    required String storeName,
    required BluetoothDevice? device,
  }) async {
    if (kIsWeb || device == null) {
      _obs.recordEvent('eod_print_skipped', metadata: {
        'reason': kIsWeb ? 'web_platform' : 'no_device',
      });
      return;
    }

    final syncLabel = report.syncStatusAtClosure ?? 'unknown';
    final closedAt  = _formatDateTime(report.closedAt.toLocal());
    final balanced  = report.isBalanced ? 'BALANCED ✓' : 'DISCREPANCY ✗';
    final discSign  = report.discrepancy >= 0 ? '+' : '';

    // Build a widget that renders as a monospace 80 mm receipt.
    final summaryWidget = _EodSummaryReceipt(
      storeName: storeName,
      closedAt: closedAt,
      totalSales: report.totalSales,
      taxCollected: report.taxCollected,
      cashExpected: report.cashExpected,
      cashActual: report.cashActual,
      discrepancy: report.discrepancy,
      discSign: discSign,
      roundingAdjustment: report.roundingAdjustment,
      bankTransferReady: report.bankTransferReady,
      balanceLabel: balanced,
      isBalanced: report.isBalanced,
      syncStatusLabel: syncLabel,
      operatorNotes: report.operatorNotes,
      closureId: report.closureId,
    );

    await printReceiptFromWidget(summaryWidget, device: device);

    _obs.recordEvent('eod_summary_printed', metadata: {
      'closure_id': report.closureId,
      'balanced': report.isBalanced.toString(),
      'bank_transfer_ready': report.bankTransferReady.toString(),
      'sync_status': syncLabel,
    });
  }

  static String _formatDateTime(DateTime dt) {
    final pad = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}';
  }
}

// ── EOD Summary Receipt Widget ────────────────────────────────────────────────
//
// 80 mm thermal receipt layout (≈ 576 px wide at 203 dpi).
// Monospace font ensures column alignment on thermal hardware.

class _EodSummaryReceipt extends StatelessWidget {
  const _EodSummaryReceipt({
    required this.storeName,
    required this.closedAt,
    required this.totalSales,
    required this.taxCollected,
    required this.cashExpected,
    required this.cashActual,
    required this.discrepancy,
    required this.discSign,
    required this.roundingAdjustment,
    required this.bankTransferReady,
    required this.balanceLabel,
    required this.isBalanced,
    required this.syncStatusLabel,
    required this.operatorNotes,
    required this.closureId,
  });

  final String storeName;
  final String closedAt;
  final double totalSales;
  final double taxCollected;
  final double cashExpected;
  final double cashActual;
  final double discrepancy;
  final String discSign;
  final double roundingAdjustment;
  final int bankTransferReady;
  final String balanceLabel;
  final bool isBalanced;
  final String syncStatusLabel;
  final String? operatorNotes;
  final String closureId;

  static const _width = 576.0; // 80 mm at 203 dpi
  static const _mono = TextStyle(
    fontFamily: 'Courier',
    fontSize: 14,
    color: Colors.black,
    height: 1.5,
  );
  static const _monoSm = TextStyle(
    fontFamily: 'Courier',
    fontSize: 11,
    color: Colors.black54,
    height: 1.5,
  );
  static const _monoBold = TextStyle(
    fontFamily: 'Courier',
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: Colors.black,
    height: 1.6,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Center(
            child: Text(
              storeName.toUpperCase(),
              style: _monoBold.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Center(
            child: Text('END OF DAY SUMMARY', style: _mono),
          ),
          Center(child: Text(closedAt, style: _monoSm)),
          const SizedBox(height: 12),
          _divider(),

          // ── Sales ─────────────────────────────────────────────────────────
          _row('Total Sales', '${totalSales.toStringAsFixed(0)} Ks'),
          _row('Tax Collected', '${taxCollected.toStringAsFixed(0)} Ks'),
          _divider(),

          // ── Cash reconciliation ───────────────────────────────────────────
          _row('Expected Cash', '${cashExpected.toStringAsFixed(0)} Ks'),
          _row('Actual Cash', '${cashActual.toStringAsFixed(0)} Ks'),
          _row('Discrepancy',
              '$discSign${discrepancy.toStringAsFixed(0)} Ks'),
          _row('Rounding Adj.',
              '${roundingAdjustment.toStringAsFixed(2)} Ks'),
          _divider(),

          // ── Bank transfer ─────────────────────────────────────────────────
          _row('BANK TRANSFER READY', '$bankTransferReady Ks',
              bold: true),
          _divider(),

          // ── Balance status ────────────────────────────────────────────────
          Center(
            child: Text(
              balanceLabel,
              style: _monoBold.copyWith(
                color: isBalanced ? Colors.green[800] : Colors.red[800],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Sync heartbeat at closure ─────────────────────────────────────
          Center(
            child: Text(
              'SYNC: ${syncStatusLabel.toUpperCase()}',
              style: _monoSm.copyWith(
                color: _syncColor(syncStatusLabel),
              ),
            ),
          ),

          if (operatorNotes != null && operatorNotes!.isNotEmpty) ...[
            _divider(),
            Text('Notes:', style: _monoSm),
            Text(operatorNotes!, style: _monoSm),
          ],

          _divider(),
          Center(
            child: Text(
              'Ref: ${closureId.substring(0, 8).toUpperCase()}',
              style: _monoSm,
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text('*** KEEP FOR YOUR RECORDS ***', style: _monoSm)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold ? _monoBold : _mono;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          '-' * 40,
          style: _monoSm,
          overflow: TextOverflow.clip,
        ),
      );

  Color _syncColor(String status) {
    switch (status.toLowerCase()) {
      case 'synced': return Colors.green;
      case 'tenantError':
      case 'forbidden': return Colors.red;
      default: return Colors.orange;
    }
  }
}

