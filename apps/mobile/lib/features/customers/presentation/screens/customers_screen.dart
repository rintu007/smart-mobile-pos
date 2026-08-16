import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/customer_providers.dart';

/// `/customers`, per route-map.md — built Sprint 32 (backlog.md M3 item 2).
/// Reached via the till's own `pos_customers_button` app-bar icon, the same
/// entry-point shape `pos_held_carts_button` established (Sprint 30). A pure
/// browse screen — tapping a row navigates to detail; attaching a customer
/// to the active cart is `CustomerPickerSheet`'s separate job.
class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(customerSearchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              key: const Key('customers_search_field'),
              decoration: const InputDecoration(
                hintText: 'Search by phone',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) =>
                  ref.read(customerSearchQueryProvider.notifier).setQuery(value),
            ),
          ),
        ),
      ),
      body: results.when(
        data: (customers) => customers.isEmpty
            ? const Center(child: Text('No customers yet', key: Key('customers_empty')))
            : ListView.builder(
                key: const Key('customers_list'),
                itemCount: customers.length,
                itemBuilder: (context, index) {
                  final customer = customers[index];
                  return ListTile(
                    key: Key('customers_row_${customer.id}'),
                    title: Text(customer.name ?? customer.phone ?? customer.id),
                    subtitle: customer.name != null && customer.phone != null
                        ? Text(customer.phone!)
                        : null,
                    onTap: () => context.push('/customers/${customer.id}'),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Could not load customers: $error')),
      ),
    );
  }
}
