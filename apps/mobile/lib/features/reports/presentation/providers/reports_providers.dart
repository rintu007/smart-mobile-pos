import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../data/repositories/drift_reports_repository.dart';
import '../../domain/entities/daily_sales_entry.dart';
import '../../domain/entities/low_stock_entry.dart';
import '../../domain/entities/stock_value_report.dart';
import '../../domain/entities/top_product_entry.dart';
import '../../domain/repositories/reports_repository.dart';

/// Manual (non-code-generated) Riverpod syntax, matching every other feature
/// provider in this codebase.
final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return DriftReportsRepository(ref.watch(appDatabaseProvider));
});

/// Gates the Reports entry point itself (`HomeScreen`) and, defensively, the
/// four report screens' own routes — docs/modules/reports/specification.md
/// §1's "visibility, not an error state" design decision, since there is no
/// network call at report-view time to surface a `403` from the way every
/// other role-gated screen in this codebase does.
final canViewReportsProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(reportsRepositoryProvider).canViewReports();
});

final dailySalesReportProvider = FutureProvider.autoDispose<List<DailySalesEntry>>((ref) {
  return ref.watch(reportsRepositoryProvider).dailySales();
});

final stockValueReportProvider = FutureProvider.autoDispose<StockValueReport>((ref) {
  return ref.watch(reportsRepositoryProvider).stockValue();
});

final lowStockReportProvider = FutureProvider.autoDispose<List<LowStockEntry>>((ref) {
  return ref.watch(reportsRepositoryProvider).lowStock();
});

/// The date range + sort a `TopProductsReportScreen` currently has selected —
/// defaults to the trailing 7 days by value, mirroring `dailySalesReportProvider`'s
/// own default window and FR-073's "value or quantity" wording order.
class TopProductsQuery {
  const TopProductsQuery({required this.from, required this.to, required this.sortBy});

  final DateTime from;
  final DateTime to;
  final TopProductsSortBy sortBy;

  TopProductsQuery copyWith({DateTime? from, DateTime? to, TopProductsSortBy? sortBy}) {
    return TopProductsQuery(
      from: from ?? this.from,
      to: to ?? this.to,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

TopProductsQuery _defaultTopProductsQuery() {
  final now = DateTime.now();
  final todayDateOnly = DateTime(now.year, now.month, now.day);
  return TopProductsQuery(
    from: todayDateOnly.subtract(const Duration(days: 6)),
    to: todayDateOnly.add(const Duration(days: 1)),
    sortBy: TopProductsSortBy.value,
  );
}

class TopProductsQueryController extends Notifier<TopProductsQuery> {
  @override
  TopProductsQuery build() => _defaultTopProductsQuery();

  void setRange({required DateTime from, required DateTime to}) {
    state = state.copyWith(from: from, to: to);
  }

  void setSortBy(TopProductsSortBy sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }
}

final topProductsQueryControllerProvider =
    NotifierProvider<TopProductsQueryController, TopProductsQuery>(
      TopProductsQueryController.new,
    );

final topProductsReportProvider = FutureProvider.autoDispose<List<TopProductEntry>>((ref) {
  final query = ref.watch(topProductsQueryControllerProvider);
  return ref
      .watch(reportsRepositoryProvider)
      .topProducts(from: query.from, to: query.to, sortBy: query.sortBy);
});
