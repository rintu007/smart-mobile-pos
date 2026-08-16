import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money.dart';
import '../providers/customer_providers.dart';

String _formatTimestamp(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// `/customers/:id`, per route-map.md — built Sprint 32 (backlog.md M3 item
/// 2, FR-051). Purchase history is fetched live, on demand — no local cache
/// (customer_repository.dart's own docstring).
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerByIdProvider(customerId));
    final history = ref.watch(customerPurchaseHistoryProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer'),
        actions: [
          IconButton(
            key: const Key('customer_edit_button'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push('/customers/$customerId/edit'),
          ),
        ],
      ),
      body: customer.when(
        data: (found) {
          if (found == null) {
            return const Center(
              child: Text('Customer not found', key: Key('customer_detail_not_found')),
            );
          }
          return ListView(
            key: const Key('customer_detail_content'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                found.name ?? found.phone ?? found.id,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (found.name != null && found.phone != null) Text(found.phone!),
              const SizedBox(height: 16),
              Text('Purchase history', style: Theme.of(context).textTheme.titleMedium),
              history.when(
                data: (sales) => sales.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No purchases yet', key: Key('customer_history_empty')),
                      )
                    : Column(
                        key: const Key('customer_history_list'),
                        children: sales
                            .map(
                              (sale) => ListTile(
                                key: Key('customer_history_sale_${sale.id}'),
                                title: Text(sale.provisionalInvoiceNumber),
                                subtitle: Text(_formatTimestamp(sale.completedAt)),
                                trailing: Text(Money(sale.grandTotalMinorUnits).format()),
                              ),
                            )
                            .toList(),
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => Text('Could not load purchase history: $error'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Could not load customer: $error')),
      ),
    );
  }
}
