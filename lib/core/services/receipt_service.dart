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
}
