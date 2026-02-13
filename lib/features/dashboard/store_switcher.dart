import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/store.dart';
import '../../core/providers/store_provider.dart';
import '../../core/providers/tax_provider.dart';

// Provider to fetch stores
final storesListProvider = FutureProvider<List<Store>>((ref) async {
  final service = ref.read(storeServiceProvider);
  return await service.fetchStores();
});

class StoreSwitcher extends ConsumerWidget {
  const StoreSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStore = ref.watch(activeStoreProvider);
    final storesListAsync = ref.watch(storesListProvider);

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Store Context',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            storesListAsync.when(
              data: (stores) {
                // Ensure activeStore is actually in the list (equality check)
                // If activeStore is null, dropdown is null (prompt shown)
                // If activeStore is set, we must find the matching item in 'stores' by ID
                Store? dropdownValue;
                if (activeStore != null) {
                  try {
                    dropdownValue = stores.firstWhere((s) => s.id == activeStore.id);
                  } catch (e) {
                    // Active store ID not found in list??
                    dropdownValue = null; 
                  }
                }

                return DropdownButton<Store>(
                  value: dropdownValue,
                  isExpanded: true,
                  hint: const Text('Select a Store'),
                  items: stores.map((Store store) {
                    return DropdownMenuItem<Store>(
                      value: store,
                      child: Text(store.storeName),
                    );
                  }).toList(),
                  onChanged: (Store? newValue) {
                    if (newValue != null) {
                      ref.read(activeStoreProvider.notifier).state = newValue;
                    }
                  },
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, stack) => Text('Error loading stores: $err'),
            ),
            const SizedBox(height: 10),
            if (activeStore != null) ...[
              Wrap(
                spacing: 8.0,
                children: [
                  _SecurityBadge(
                    label: 'GPS: ${activeStore.isGeofenceEnabled ? "ON" : "OFF"}',
                    isValid: activeStore.isGeofenceEnabled,
                    color: Colors.green,
                  ),
                  _SecurityBadge(
                    label: 'WiFi: ${activeStore.authorizedBssid ?? "NONE"}',
                    isValid: activeStore.authorizedBssid != null,
                    color: Colors.blue,
                  ),
                   _SecurityBadge(
                    label: 'Tax: ${activeStore.taxRate}%',
                    isValid: true,
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Tax Rate'),
                  onPressed: () {
                    _showEditTaxDialog(context, ref, activeStore);
                  },
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showEditTaxDialog(BuildContext context, WidgetRef ref, Store store) {
    final controller = TextEditingController(text: store.taxRate.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Tax Rate'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(suffixText: '%'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newRate = double.tryParse(controller.text) ?? 0.0;
                
                // Use TaxRateNotifier to handle update & audit
                await ref.read(taxRateProvider.notifier).updateTaxRateOverride(newRate, 'Manual Dashboard Override');
                
                // Update local UI immediately (optimistic)
                final updatedStore = store.copyWith(taxRate: newRate);
                ref.read(activeStoreProvider.notifier).state = updatedStore;
                
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  final String label;
  final bool isValid;
  final Color color;

  const _SecurityBadge({required this.label, required this.isValid, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        isValid ? Icons.check_circle : Icons.info,
        color: Colors.white,
        size: 16,
      ),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: isValid ? color : Colors.grey,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
