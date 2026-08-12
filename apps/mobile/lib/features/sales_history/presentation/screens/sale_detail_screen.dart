import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../providers/sales_history_providers.dart';

String _formatTimestamp(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// `/sales-history/:id`, per route-map.md — built Sprint 10.
class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(saleDetailProvider(saleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Sale detail')),
      body: detail.when(
        data: (sale) {
          if (sale == null) {
            return const Center(
              child: Text('Sale not found', key: Key('sale_detail_not_found')),
            );
          }
          return ListView(
            key: const Key('sale_detail_content'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                sale.provisionalInvoiceNumber,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(_formatTimestamp(sale.completedAt)),
              const SizedBox(height: 16),
              ...sale.lines.map(
                (line) => ListTile(
                  key: Key('sale_detail_line_${line.productId}'),
                  title: Text(line.productName ?? line.productId),
                  subtitle: Text(
                    'x${line.quantity} @ ${Money(line.unitPriceMinorUnits).format()}',
                  ),
                  trailing: Text(Money(line.lineTotalMinorUnits).format()),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    Money(sale.grandTotalMinorUnits).format(),
                    key: const Key('sale_detail_total'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Could not load sale: $error')),
      ),
    );
  }
}
