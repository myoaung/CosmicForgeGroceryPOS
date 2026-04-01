import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/store_provider.dart';
import '../widgets/storage_usage_card.dart';
import '../widgets/sync_status_card.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: isAdmin
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SyncStatusCard(),
                  const SizedBox(height: 12),
                  const StorageUsageCard(),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueGrey,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Provision New POS Terminal'),
                    onPressed: () {
                      final scope = ref.read(activeTenantStoreScopeProvider);
                      if (scope == null) return;
                      
                      final payload = jsonEncode({
                        'tenant_id': scope.tenantId,
                        'store_id': scope.storeId,
                        'device_role': 'POS_TERMINAL',
                        'timestamp': DateTime.now().toIso8601String(),
                      });

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Device Provisioning QR'),
                          content: SizedBox(
                            width: 300,
                            height: 300,
                            child: QrImageView(
                              data: payload,
                              version: QrVersions.auto,
                              size: 300.0,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ],
              )
            : const Center(
                child: Text('Access denied: admin role required.'),
              ),
      ),
    );
  }
}
