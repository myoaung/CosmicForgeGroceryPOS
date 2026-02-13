
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery/core/providers/database_provider.dart';

// Provider to get pending sync count
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.transactions).watch().map((transactions) {
    return transactions.where((t) => !t.isSynced).length;
  });
});

class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingSyncCountProvider);

    return Card(
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_sync, color: Colors.blue),
                SizedBox(width: 8),
                Text('Global Sync Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            pendingAsync.when(
              data: (count) {
                final isSynced = count == 0;
                return Row(
                  children: [
                    Icon(
                      isSynced ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: isSynced ? Colors.green : Colors.orange,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSynced ? 'All Systems Operational' : 'Sync Required',
                          style: TextStyle(
                            color: isSynced ? Colors.green[800] : Colors.orange[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text('$count pending transactions'),
                      ],
                    )
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, text) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
