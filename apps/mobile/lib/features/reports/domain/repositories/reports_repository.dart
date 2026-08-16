import '../entities/daily_sales_entry.dart';
import '../entities/low_stock_entry.dart';
import '../entities/stock_value_report.dart';
import '../entities/top_product_entry.dart';

/// FR-073's own "quantity or value" choice.
enum TopProductsSortBy { quantity, value }

/// Abstract interface only, per mobile-structure.md §2. Every method here is
/// a pure local Drift aggregation — no network call, no injected remote data
/// source (unlike every other feature repository in this codebase), since
/// FR-071–074 are all classified "Fully offline" and Sprint 36/37 already
/// keep the underlying `stock_movements`/`sales`/`shop_settings` caches
/// current via the ordinary sync cycle (docs/modules/reports/specification.md §1).
abstract class ReportsRepository {
  /// FR-071 — today's total plus the trailing 7 days, oldest first, one
  /// entry per calendar day (`totalMinorUnits: 0` for a day with nothing).
  Future<List<DailySalesEntry>> dailySales();

  /// FR-072 — `Σ(derived balance × price_minor_units)` across every product.
  Future<StockValueReport> stockValue();

  /// FR-073 — `from` inclusive, `to` exclusive, matching every other
  /// date-range query in this codebase (stock-movements/specification.md's
  /// own precedent). Products with zero quantity sold in range are omitted,
  /// not returned as a false zero-row.
  Future<List<TopProductEntry>> topProducts({
    required DateTime from,
    required DateTime to,
    required TopProductsSortBy sortBy,
  });

  /// FR-074 — every product strictly below the configured threshold, sorted
  /// furthest-under-threshold first.
  Future<List<LowStockEntry>> lowStock();

  /// The cached role-probe result (docs/modules/reports/specification.md
  /// §1's third gap) — `false` until the device has synced at least once
  /// while signed in as a Manager/Owner, fail-closed by default.
  Future<bool> canViewReports();
}
