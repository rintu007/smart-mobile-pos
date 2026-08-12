import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money.dart';
import '../providers/sales_history_providers.dart';

/// No formatting package dependency yet (no `intl` — matches
/// add_product_screen.dart's precedent of not reaching for a package until
/// a second place actually needs the same thing) — plain manual formatting.
String _formatTimestamp(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// `/sales-history`, per route-map.md — built Sprint 10. Local-only: reads
/// straight from this device's own Drift database, no network call.
class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(salesHistoryListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sales history')),
      body: sales.when(
        data: (items) => items.isEmpty
            ? const Center(
                child: Text('No sales yet', key: Key('sales_history_empty')),
              )
            : ListView.builder(
                key: const Key('sales_history_list'),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final sale = items[index];
                  return ListTile(
                    key: Key('sales_history_sale_${sale.id}'),
                    title: Text(sale.provisionalInvoiceNumber),
                    subtitle: Text(_formatTimestamp(sale.completedAt)),
                    trailing: Text(Money(sale.grandTotalMinorUnits).format()),
                    onTap: () => context.push('/sales-history/${sale.id}'),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Could not load sales history: $error')),
      ),
    );
  }
}
