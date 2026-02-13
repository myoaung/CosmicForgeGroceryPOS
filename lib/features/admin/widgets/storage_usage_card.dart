
import 'package:flutter/material.dart';

class StorageUsageCard extends StatelessWidget {
  const StorageUsageCard({super.key});

  @override
  Widget build(BuildContext context) {
    // In a real app, fetch this from Supabase Storage API or edge function
    const double usageMb = 45.2;
    const double limitMb = 500.0;
    const double percentage = usageMb / limitMb;

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
                Icon(Icons.storage, color: Colors.purple),
                SizedBox(width: 8),
                Text('Cloud Storage Usage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[200],
              color: Colors.purple,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${usageMb.toStringAsFixed(1)} MB used'),
                Text('${limitMb.toStringAsFixed(0)} MB limit'),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${(percentage * 100).toStringAsFixed(1)}% of quota',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
