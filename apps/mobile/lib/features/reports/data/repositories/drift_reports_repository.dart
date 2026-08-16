import 'package:drift/drift.dart';

import '../../../../core/database/database.dart';
import '../../domain/entities/daily_sales_entry.dart';
import '../../domain/entities/low_stock_entry.dart';
import '../../domain/entities/stock_value_report.dart';
import '../../domain/entities/top_product_entry.dart';
import '../../domain/repositories/reports_repository.dart';

/// Concrete implementation, per mobile-structure.md §2. Every query reads
/// already-synced local tables directly — no injected remote function,
/// unlike every other Drift repository in this codebase (there is nothing to
/// inject: `ReportsRepository`'s own docstring explains why).
class DriftReportsRepository implements ReportsRepository {
  DriftReportsRepository(this._db);

  final AppDatabase _db;

  static const _defaultLowStockThreshold = 5;

  Future<Map<String, double>> _balanceByProduct() async {
    final movements = await _db.select(_db.stockMovements).get();
    final balances = <String, double>{};
    for (final movement in movements) {
      balances[movement.productId] = (balances[movement.productId] ?? 0) + movement.quantityDelta;
    }
    return balances;
  }

  @override
  Future<List<DailySalesEntry>> dailySales() async {
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final sinceDateOnly = todayDateOnly.subtract(const Duration(days: 6));

    final rows =
        await (_db.select(_db.sales)..where(
              (t) =>
                  t.status.equals('completed') &
                  t.completedAt.isBiggerOrEqualValue(sinceDateOnly),
            ))
            .get();

    final totalsByDate = <DateTime, int>{};
    for (final row in rows) {
      final completedAt = row.completedAt;
      if (completedAt == null) continue;
      final dateOnly = DateTime(completedAt.year, completedAt.month, completedAt.day);
      totalsByDate[dateOnly] = (totalsByDate[dateOnly] ?? 0) + row.grandTotalMinorUnits;
    }

    return List.generate(7, (offset) {
      final date = sinceDateOnly.add(Duration(days: offset));
      return DailySalesEntry(date: date, totalMinorUnits: totalsByDate[date] ?? 0);
    });
  }

  @override
  Future<StockValueReport> stockValue() async {
    final products = await _db.select(_db.products).get();
    final balances = await _balanceByProduct();

    var total = 0;
    final entries = <StockValueEntry>[];
    for (final product in products) {
      final balance = balances[product.id] ?? 0;
      final value = (balance * product.priceMinorUnits).round();
      total += value;
      entries.add(
        StockValueEntry(
          productId: product.id,
          productName: product.name,
          balance: balance,
          valueMinorUnits: value,
        ),
      );
    }
    entries.sort((a, b) => b.valueMinorUnits.compareTo(a.valueMinorUnits));

    return StockValueReport(totalMinorUnits: total, entries: entries);
  }

  @override
  Future<List<TopProductEntry>> topProducts({
    required DateTime from,
    required DateTime to,
    required TopProductsSortBy sortBy,
  }) async {
    final salesInRange =
        await (_db.select(_db.sales)..where(
              (t) =>
                  t.status.equals('completed') &
                  t.completedAt.isBiggerOrEqualValue(from) &
                  t.completedAt.isSmallerThanValue(to),
            ))
            .get();
    final saleIds = salesInRange.map((sale) => sale.id).toSet();
    if (saleIds.isEmpty) return [];

    final lineItems =
        await (_db.select(_db.saleLineItems)..where((t) => t.saleId.isIn(saleIds))).get();
    final products = await _db.select(_db.products).get();
    final productsById = {for (final product in products) product.id: product};

    final quantityByProduct = <String, double>{};
    final valueByProduct = <String, int>{};
    for (final item in lineItems) {
      quantityByProduct[item.productId] = (quantityByProduct[item.productId] ?? 0) + item.quantity;
      valueByProduct[item.productId] =
          (valueByProduct[item.productId] ?? 0) + item.lineTotalMinorUnits;
    }

    final entries = quantityByProduct.keys
        .map(
          (productId) => TopProductEntry(
            productId: productId,
            productName: productsById[productId]?.name ?? 'Unknown product',
            quantity: quantityByProduct[productId]!,
            valueMinorUnits: valueByProduct[productId] ?? 0,
          ),
        )
        .toList();

    entries.sort(
      (a, b) => sortBy == TopProductsSortBy.quantity
          ? b.quantity.compareTo(a.quantity)
          : b.valueMinorUnits.compareTo(a.valueMinorUnits),
    );

    return entries;
  }

  @override
  Future<List<LowStockEntry>> lowStock() async {
    final cache = await (_db.select(
      _db.shopSettingsCache,
    )..where((t) => t.id.equals('current'))).getSingleOrNull();
    final threshold = cache?.lowStockThresholdQuantity ?? _defaultLowStockThreshold;

    final products = await _db.select(_db.products).get();
    final balances = await _balanceByProduct();

    final entries = <LowStockEntry>[];
    for (final product in products) {
      final balance = balances[product.id] ?? 0;
      if (balance < threshold) {
        entries.add(
          LowStockEntry(
            productId: product.id,
            productName: product.name,
            balance: balance,
            thresholdQuantity: threshold,
          ),
        );
      }
    }
    entries.sort((a, b) => a.balance.compareTo(b.balance));

    return entries;
  }

  @override
  Future<bool> canViewReports() async {
    final cache = await (_db.select(
      _db.shopSettingsCache,
    )..where((t) => t.id.equals('current'))).getSingleOrNull();
    return cache?.canViewReports ?? false;
  }
}
