import 'package:flutter/material.dart';
import '../pos/screens/pos_screen.dart';
import 'store_switcher.dart';
import '../history/screens/history_screen.dart';
import '../reports/screens/daily_closing_screen.dart';
import '../products/screens/product_list_screen.dart';
import '../admin/screens/admin_dashboard_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cosmic Forge POS'),
        actions: [
          const StoreSwitcher(),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.assessment),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyClosingScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Placeholder for settings
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('POS Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
             ListTile(
              leading: const Icon(Icons.point_of_sale),
              title: const Text('POS Terminal'),
              onTap: () => Navigator.pop(context), // Already here
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Transaction History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.assessment),
              title: const Text('Daily Closing Report'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyClosingScreen()));
              },
            ),
             ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Product Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
              title: const Text('App Owner Dashboard'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
              },
            ),
          ],
        ),
      ),
      body: const POSLayout(),
    );
  }
}
