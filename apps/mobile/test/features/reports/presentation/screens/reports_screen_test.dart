import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/reports/domain/entities/daily_sales_entry.dart';
import 'package:mobile/features/reports/domain/entities/low_stock_entry.dart';
import 'package:mobile/features/reports/domain/entities/stock_value_report.dart';
import 'package:mobile/features/reports/domain/entities/top_product_entry.dart';
import 'package:mobile/features/reports/domain/repositories/reports_repository.dart';
import 'package:mobile/features/reports/presentation/providers/reports_providers.dart';
import 'package:mobile/features/reports/presentation/screens/daily_sales_report_screen.dart';
import 'package:mobile/features/reports/presentation/screens/low_stock_report_screen.dart';
import 'package:mobile/features/reports/presentation/screens/reports_screen.dart';
import 'package:mobile/features/reports/presentation/screens/stock_value_report_screen.dart';
import 'package:mobile/features/reports/presentation/screens/top_products_report_screen.dart';

/// A fake, not a mock, matching this codebase's own established convention.
class _FakeReportsRepository implements ReportsRepository {
  _FakeReportsRepository({
    this.dailySalesResult = const [],
    this.stockValueResult = const StockValueReport(totalMinorUnits: 0, entries: []),
    this.topProductsResult = const [],
    this.lowStockResult = const [],
  });

  final List<DailySalesEntry> dailySalesResult;
  final StockValueReport stockValueResult;
  final List<TopProductEntry> topProductsResult;
  final List<LowStockEntry> lowStockResult;

  @override
  Future<List<DailySalesEntry>> dailySales() async => dailySalesResult;

  @override
  Future<StockValueReport> stockValue() async => stockValueResult;

  @override
  Future<List<TopProductEntry>> topProducts({
    required DateTime from,
    required DateTime to,
    required TopProductsSortBy sortBy,
  }) async => topProductsResult;

  @override
  Future<List<LowStockEntry>> lowStock() async => lowStockResult;

  // Not exercised by these screens (they trust HomeScreen's own gate, per
  // ReportsScreen's docstring) — a fixed value is sufficient here.
  @override
  Future<bool> canViewReports() async => true;
}

Widget _wrap(Widget child, {ReportsRepository? repository}) {
  return ProviderScope(
    overrides: [
      if (repository != null) reportsRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('ReportsScreen renders all four tiles', (tester) async {
    await tester.pumpWidget(_wrap(const ReportsScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reports_daily_sales_tile')), findsOneWidget);
    expect(find.byKey(const Key('reports_top_products_tile')), findsOneWidget);
    expect(find.byKey(const Key('reports_stock_value_tile')), findsOneWidget);
    expect(find.byKey(const Key('reports_low_stock_tile')), findsOneWidget);
  });

  testWidgets('DailySalesReportScreen shows an empty state with no sales', (tester) async {
    await tester.pumpWidget(
      _wrap(const DailySalesReportScreen(), repository: _FakeReportsRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily_sales_empty')), findsOneWidget);
  });

  testWidgets("DailySalesReportScreen shows today's total and the trailing days", (tester) async {
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final entries = List.generate(
      7,
      (i) => DailySalesEntry(
        date: todayDateOnly.subtract(Duration(days: 6 - i)),
        totalMinorUnits: i == 6 ? 1500 : 0,
      ),
    );

    await tester.pumpWidget(
      _wrap(
        const DailySalesReportScreen(),
        repository: _FakeReportsRepository(dailySalesResult: entries),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily_sales_today')), findsOneWidget);
    // Appears twice: once in the highlighted "Today's total" row, once more
    // in the full 7-day list below it (today is also the list's last entry).
    expect(find.text('\u{20B9}15.00'), findsNWidgets(2));
  });

  testWidgets('StockValueReportScreen shows the total and a per-product breakdown', (tester) async {
    const report = StockValueReport(
      totalMinorUnits: 4500,
      entries: [
        StockValueEntry(productId: 'p1', productName: 'Coffee', balance: 7, valueMinorUnits: 3500),
        StockValueEntry(productId: 'p2', productName: 'Sugar', balance: 5, valueMinorUnits: 1000),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        const StockValueReportScreen(),
        repository: _FakeReportsRepository(stockValueResult: report),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stock_value_total')), findsOneWidget);
    expect(find.byKey(const Key('stock_value_p1')), findsOneWidget);
    expect(find.byKey(const Key('stock_value_p2')), findsOneWidget);
  });

  testWidgets('LowStockReportScreen shows a warning row per product below threshold', (tester) async {
    const entries = [
      LowStockEntry(productId: 'p1', productName: 'Coffee', balance: 2, thresholdQuantity: 10),
    ];

    await tester.pumpWidget(
      _wrap(const LowStockReportScreen(), repository: _FakeReportsRepository(lowStockResult: entries)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('low_stock_p1')), findsOneWidget);
    expect(find.text('2 / 10'), findsOneWidget);
  });

  testWidgets('LowStockReportScreen shows the empty state when nothing is below threshold', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const LowStockReportScreen(), repository: _FakeReportsRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('low_stock_empty')), findsOneWidget);
  });

  testWidgets('TopProductsReportScreen shows a ranked list', (tester) async {
    const entries = [
      TopProductEntry(productId: 'p1', productName: 'Coffee', quantity: 5, valueMinorUnits: 2500),
      TopProductEntry(productId: 'p2', productName: 'Sugar', quantity: 3, valueMinorUnits: 600),
    ];

    await tester.pumpWidget(
      _wrap(
        const TopProductsReportScreen(),
        repository: _FakeReportsRepository(topProductsResult: entries),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('top_product_p1')), findsOneWidget);
    expect(find.byKey(const Key('top_product_p2')), findsOneWidget);
  });

  testWidgets('TopProductsReportScreen shows the empty state with no sales in range', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const TopProductsReportScreen(), repository: _FakeReportsRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('top_products_empty')), findsOneWidget);
  });
}
