import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../domain/repositories/reports_repository.dart';
import '../providers/reports_providers.dart';

/// `/reports/top-products` — FR-073: ranked by quantity or value sold over a
/// user-selected date range, defaulting to the trailing 7 days by value.
class TopProductsReportScreen extends ConsumerWidget {
  const TopProductsReportScreen({super.key});

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final query = ref.read(topProductsQueryControllerProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(start: query.from, end: query.to),
    );
    if (picked != null) {
      ref
          .read(topProductsQueryControllerProvider.notifier)
          .setRange(from: picked.start, to: picked.end.add(const Duration(days: 1)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(topProductsReportProvider);
    final query = ref.watch(topProductsQueryControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Top products')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('top_products_date_range_button'),
                    onPressed: () => _pickRange(context, ref),
                    child: Text('${_formatDate(query.from)} – ${_formatDate(query.to)}'),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<TopProductsSortBy>(
                  key: const Key('top_products_sort_dropdown'),
                  value: query.sortBy,
                  items: const [
                    DropdownMenuItem(value: TopProductsSortBy.value, child: Text('By value')),
                    DropdownMenuItem(value: TopProductsSortBy.quantity, child: Text('By quantity')),
                  ],
                  onChanged: (sortBy) {
                    if (sortBy != null) {
                      ref.read(topProductsQueryControllerProvider.notifier).setSortBy(sortBy);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: report.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Text('No sales in this range', key: Key('top_products_empty')),
                  );
                }
                return ListView.builder(
                  key: const Key('top_products_list'),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return ListTile(
                      key: Key('top_product_${entry.productId}'),
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(entry.productName),
                      subtitle: Text('Qty: ${_formatQuantity(entry.quantity)}'),
                      trailing: Text(Money(entry.valueMinorUnits).format()),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  const Center(child: Text('Could not load the top products report. Try again.')),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatQuantity(double quantity) =>
      quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toStringAsFixed(2);
}
