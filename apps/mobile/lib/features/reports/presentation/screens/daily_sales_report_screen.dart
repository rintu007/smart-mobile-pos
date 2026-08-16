import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../providers/reports_providers.dart';

/// `/reports/daily-sales` — FR-071: today's total plus the trailing 7 days.
class DailySalesReportScreen extends ConsumerWidget {
  const DailySalesReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(dailySalesReportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily sales')),
      body: report.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('No sales yet', key: Key('daily_sales_empty')));
          }
          final today = entries.last;
          return ListView(
            key: const Key('daily_sales_list'),
            children: [
              ListTile(
                key: const Key('daily_sales_today'),
                title: const Text("Today's total"),
                trailing: Text(
                  Money(today.totalMinorUnits).format(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(),
              ...entries.reversed.map(
                (entry) => ListTile(
                  key: Key('daily_sales_${entry.date.toIso8601String()}'),
                  title: Text(_formatDate(entry.date)),
                  trailing: Text(Money(entry.totalMinorUnits).format()),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Could not load the daily sales report. Try again.')),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
