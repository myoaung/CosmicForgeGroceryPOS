
import 'package:flutter/material.dart';
import '../../admin/widgets/sync_status_card.dart';
import '../../admin/widgets/storage_usage_card.dart';
import '../../admin/models/admin_health_summary.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Simulated Security Check
    // In real app: if (Supabase.instance.client.auth.currentUser?.id != 'MY_UID') return AccessDenied();
    const bool isAppOwner = true; // Toggle for simulation

    if (!isAppOwner) {
      return const Scaffold(body: Center(child: Text('ACCESS DENIED')));
    }

    // Mock Data for Admin SQL View
    final List<AdminHealthSummary> tenants = [
      AdminHealthSummary(
        tenantId: 't1', 
        businessName: 'Yangon Mart', 
        lastSync: DateTime.now().subtract(const Duration(minutes: 5)), 
        storageUsageMb: 150.5
      ),
      AdminHealthSummary(
        tenantId: 't2', 
        businessName: 'Mandalay Grocers', 
        lastSync: DateTime.now().subtract(const Duration(hours: 2)), 
        storageUsageMb: 450.2
      ),
       AdminHealthSummary(
        tenantId: 't3', 
        businessName: 'Shan State Traders', 
        lastSync: DateTime.now().subtract(const Duration(days: 1)), 
        storageUsageMb: 890.0
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('GOD MODE: App Owner'),
        backgroundColor: Colors.red[900], // Distinctive color
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SyncStatusCard(),
            const SizedBox(height: 16),
            const StorageUsageCard(),
            const SizedBox(height: 16),
            
            // High-Level Tenant Summary
            const Text('Multi-Tenant Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tenants.length, 
              itemBuilder: (context, index) {
                final tenant = tenants[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.store),
                    title: Text(tenant.businessName), // Uses business_name
                    subtitle: Text('Last Sync: ${tenant.lastSync.toString().substring(0, 16)}'),
                    trailing: Text('${tenant.storageUsageMb.toStringAsFixed(1)} MB'),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.build),
                title: const Text('Maintenance Mode'),
                subtitle: const Text('Disable sync for all tenants'),
                trailing: Switch(value: false, onChanged: (v) {}),
              ),
            )
          ],
        ),
      ),
    );
  }
}
