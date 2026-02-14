import 'package:flutter/material.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:intl/intl.dart';

class ReceiptLayout extends StatelessWidget {
  final Transaction transaction;
  final List<TransactionItem> items;
  final String storeName;

  const ReceiptLayout({
    super.key,
    required this.transaction,
    required this.items,
    required this.storeName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Text(storeName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Pyidaungsu')),
        const SizedBox(height: 5),
        const Text('Grocery POS', style: TextStyle(fontSize: 16)),
        const Divider(thickness: 2),
        Align(
          alignment: Alignment.centerLeft, 
          child: Text('Order: ${transaction.id.substring(0, 8)}', style: const TextStyle(fontSize: 12))
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(transaction.timestamp)}', style: const TextStyle(fontSize: 12))
        ),
        const Divider(),
        // Items Table
        for (var item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(item.productName, style: const TextStyle(fontFamily: 'Pyidaungsu', fontSize: 14))),
                Expanded(flex: 1, child: Text('${item.quantity.toInt()}x', textAlign: TextAlign.right, style: const TextStyle(fontSize: 14))),
                Expanded(flex: 2, child: Text('${(item.quantity * item.unitPrice).toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 14))),
              ],
            ),
          ),
        const Divider(),
        _buildRow('Subtotal:', transaction.subtotal),
        _buildRow('Tax:', transaction.taxAmount),
        const Divider(thickness: 2),
        _buildRow('Total:', transaction.totalAmount, isBold: true, scale: 1.5),
        const SizedBox(height: 20),
        const Text('Thank You!', style: TextStyle(fontFamily: 'Pyidaungsu')),
        const SizedBox(height: 40), // Paper feed padding
      ],
    );
  }

  Widget _buildRow(String label, double amount, {bool isBold = false, double scale = 1.0}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 14 * scale)),
          Text('${amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 14 * scale)),
        ],
      ),
    );
  }
}
