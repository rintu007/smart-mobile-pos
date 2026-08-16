import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/reports` — the hub screen linking to the four core reports
/// (docs/modules/reports/specification.md §9). Reached only when
/// `HomeScreen` itself has already decided to show the entry point
/// (`canViewReportsProvider`); this screen does not re-check it, matching
/// `AddProductScreen`'s own precedent of trusting the caller's own nav gate
/// rather than duplicating it.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        key: const Key('reports_list'),
        children: [
          ListTile(
            key: const Key('reports_daily_sales_tile'),
            leading: const Icon(Icons.calendar_today),
            title: const Text('Daily sales'),
            subtitle: const Text("Today's total and the trailing 7 days"),
            onTap: () => context.push('/reports/daily-sales'),
          ),
          ListTile(
            key: const Key('reports_top_products_tile'),
            leading: const Icon(Icons.trending_up),
            title: const Text('Top products'),
            subtitle: const Text('Ranked by quantity or value sold'),
            onTap: () => context.push('/reports/top-products'),
          ),
          ListTile(
            key: const Key('reports_stock_value_tile'),
            leading: const Icon(Icons.inventory_2),
            title: const Text('Stock value'),
            subtitle: const Text('Current stock, valued at selling price'),
            onTap: () => context.push('/reports/stock-value'),
          ),
          ListTile(
            key: const Key('reports_low_stock_tile'),
            leading: const Icon(Icons.warning_amber),
            title: const Text('Low stock'),
            subtitle: const Text('Products below their configured threshold'),
            onTap: () => context.push('/reports/low-stock'),
          ),
        ],
      ),
    );
  }
}
