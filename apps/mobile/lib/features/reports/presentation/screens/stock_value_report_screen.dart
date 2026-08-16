import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../providers/reports_providers.dart';

/// `/reports/stock-value` — FR-072: `Σ(derived balance × price)` across
/// every product, against selling price (no separate cost field exists).
class StockValueReportScreen extends ConsumerWidget {
  const StockValueReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(stockValueReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock value')),
      body: report.when(
        data: (result) {
          if (result.entries.isEmpty) {
            return const Center(child: Text('No products yet', key: Key('stock_value_empty')));
          }
          return ListView(
            key: const Key('stock_value_list'),
            children: [
              ListTile(
                key: const Key('stock_value_total'),
                title: const Text('Total stock value'),
                trailing: Text(
                  Money(result.totalMinorUnits).format(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(),
              ...result.entries.map(
                (entry) => ListTile(
                  key: Key('stock_value_${entry.productId}'),
                  title: Text(entry.productName),
                  subtitle: Text('Balance: ${_formatQuantity(entry.balance)}'),
                  trailing: Text(Money(entry.valueMinorUnits).format()),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Could not load the stock value report. Try again.')),
      ),
    );
  }

  String _formatQuantity(double quantity) =>
      quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toStringAsFixed(2);
}
