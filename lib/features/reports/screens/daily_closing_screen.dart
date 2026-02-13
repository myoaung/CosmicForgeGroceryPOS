import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/report_provider.dart';

class DailyClosingScreen extends ConsumerStatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  ConsumerState<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends ConsumerState<DailyClosingScreen> {
  @override
  void initState() {
    super.initState();
    // Generate fetching on init
    Future.microtask(() => ref.read(dailyClosingProvider.notifier).generateReport());
  }

  @override
  Widget build(BuildContext context) {
    final reportState = ref.watch(dailyClosingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Closing Report')),
      body: reportState.when(
        data: (report) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text('Closing for ${DateFormat('yyyy-MM-dd').format(report.date)}', 
                        style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 20),
                      _buildRow('Transactions', '${report.transactionCount}'),
                      const Divider(),
                      _buildRow('Gross Sales', '${report.grossSales.toStringAsFixed(0)} MMK'),
                      _buildRow('Total Tax', '${report.totalTax.toStringAsFixed(0)} MMK'),
                      _buildRow('Rounding Adj.', '${report.roundingDiff.toStringAsFixed(0)} MMK', isDim: true),
                      const Divider(thickness: 2),
                      _buildRow('NET CASH', '${report.netCash.toStringAsFixed(0)} MMK', isBold: true, scale: 1.5),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('PRINT Z-REPORT'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printing Z-Report...')));
                },
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, bool isDim = false, double scale = 1.0}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 16 * scale, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isDim ? Colors.grey : Colors.black
          )),
          Text(value, style: TextStyle(
            fontSize: 16 * scale, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isDim ? Colors.grey : Colors.black
          )),
        ],
      ),
    );
  }
}
