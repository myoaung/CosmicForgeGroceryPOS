import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grocery/features/auth/auth_provider.dart';

class QRProvisionScreen extends ConsumerStatefulWidget {
  const QRProvisionScreen({super.key});

  @override
  ConsumerState<QRProvisionScreen> createState() => _QRProvisionScreenState();
}

class _QRProvisionScreenState extends ConsumerState<QRProvisionScreen> {
  bool _isProcessing = false;
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _isProcessing = true);

    try {
      final payload = jsonDecode(barcode!.rawValue!);
      final tenantId = payload['tenant_id'];
      final storeId = payload['store_id'];
      final deviceRole = payload['device_role'];

      if (tenantId == null || storeId == null) {
        throw const FormatException('Invalid QR Payload Structure');
      }

      // 1. Secure Storage: Save Tink/Encrypted keys
      final secureStorage = ref.read(secureStorageServiceProvider);
      
      final mockUser = User(
        id: 'device-provisioned',
        appMetadata: {},
        userMetadata: {'tenant_id': tenantId, 'store_id': storeId, 'role': 'cashier'},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      
      final mockSession = Session(
        accessToken: 'device_provisioned_${tenantId}_$storeId',
        refreshToken: 'refresh_mock',
        expiresIn: 360000,
        tokenType: 'bearer',
        user: mockUser,
      );
      
      await secureStorage.persistSession(mockSession);

      // 2. Initialize Drift DB with secure keys (handled automatically on session change)
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device Provisioned! Role: $deviceRole'),
          backgroundColor: Colors.green,
        ),
      );

      // Successfully provisioned, pop back to trigger auth state listener
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Provisioning Failed: $e')),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isProcessing = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provision Device')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(),
            ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.black54,
                child: const Text(
                  'Scan Admin QR to provision this device',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
