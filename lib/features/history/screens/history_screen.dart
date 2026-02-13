import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/history_provider.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(historyProvider.notifier).refresh(),
          )
        ],
      ),
      body: historyState.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('No transactions found.'));
          }
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final txWithItems = transactions[index];
              final tx = txWithItems.transaction;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: tx.isSynced ? Colors.green[100] : Colors.orange[100],
                    child: Icon(
                      tx.isSynced ? Icons.cloud_done : Icons.cloud_upload,
                      color: tx.isSynced ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text('Order #${tx.id.substring(0, 8)}...'),
                  subtitle: Text(DateFormat('yyyy-MM-dd HH:mm a').format(tx.timestamp)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${tx.totalAmount.toStringAsFixed(0)} MMK', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${txWithItems.items.length} Items', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  onTap: () {
                   _showTransactionDetails(context, txWithItems);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, TransactionWithItems txWithItems) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final tx = txWithItems.transaction;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, color: Colors.grey[300], margin: const EdgeInsets.only(bottom: 20))),
                  Text('Transaction Details', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('ID:'), SelectableText(tx.id, style: const TextStyle(fontFamily: 'Courier'))
                  ]),
                   Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Date:'), Text(DateFormat('yyyy-MM-dd HH:mm').format(tx.timestamp))
                  ]),
                   Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Status:'), 
                    Chip(
                      label: Text(tx.isSynced ? 'Synced' : 'Pending'),
                      backgroundColor: tx.isSynced ? Colors.green[100] : Colors.orange[100],
                      labelStyle: TextStyle(color: tx.isSynced ? Colors.green[800] : Colors.orange[800]),
                      visualDensity: VisualDensity.compact,
                    )
                  ]),
                  const Divider(height: 30),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: txWithItems.items.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = txWithItems.items[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.productName, style: const TextStyle(fontFamily: 'Pyidaungsu')), // Font support
                          subtitle: Text('${item.quantity} x ${item.unitPrice}'),
                          trailing: Text('${(item.quantity * item.unitPrice).toStringAsFixed(0)}'),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  _buildSummaryRow('Subtotal', tx.subtotal),
                  _buildSummaryRow('Tax', tx.taxAmount),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Total', tx.totalAmount, isBold: true),
                  const SizedBox(height: 20),
                  
                  // Reprint Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('REPRINT RECEIPT'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                      onPressed: () async {
                         // TODO: Get actual device from settings
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Finding Printer...')));
                         
                         // Instance of ReceiptService
                         // In real app, use provider: final receiptService = ref.read(receiptServiceProvider);
                         // For now, placeholder or direct instantiate if needed, but best to use provider.
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 14)),
          Text('${amount.toStringAsFixed(0)} MMK', style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 18 : 14)),
        ],
      ),
    );
  }
}
