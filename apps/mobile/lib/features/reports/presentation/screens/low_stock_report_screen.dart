import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reports_providers.dart';

/// `/reports/low-stock` — FR-074: every product below
/// `shop_settings.low_stock_threshold_quantity`, furthest-under first
/// (BR-045's own explicit ordering).
class LowStockReportScreen extends ConsumerWidget {
  const LowStockReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(lowStockReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Low stock')),
      body: report.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Text('Nothing is below threshold', key: Key('low_stock_empty')),
            );
          }
          return ListView.builder(
            key: const Key('low_stock_list'),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                key: Key('low_stock_${entry.productId}'),
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                title: Text(entry.productName),
                trailing: Text('${_formatQuantity(entry.balance)} / ${entry.thresholdQuantity}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Could not load the low stock report. Try again.')),
      ),
    );
  }

  String _formatQuantity(double quantity) =>
      quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toStringAsFixed(2);
}
