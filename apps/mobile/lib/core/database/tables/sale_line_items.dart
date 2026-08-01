import 'package:drift/drift.dart';

import 'sales.dart';

/// M0-minimal slice of schema-server.md's `sale_line_items` — omits
/// `variant_id` (V2+ stub), `hsn_sac_code_at_sale`/`tax_rate_basis_points`/
/// `line_discount_minor_units`/`line_tax_minor_units` (M2 scope, see sales.dart's
/// comment), matching the till screen's M0 scope exactly.
class SaleLineItems extends Table {
  TextColumn get id => text()();

  TextColumn get saleId => text().references(Sales, #id)();

  TextColumn get productId => text()();

  /// Same stated float simplification as stock_movements.dart's
  /// `quantityDelta` — NUMERIC(14,3) on the server.
  RealColumn get quantity => real()();

  /// Snapshot at sale time, independent of later price changes. `integer()`,
  /// not `int64()` — see products.dart's comment on `priceMinorUnits`.
  IntColumn get unitPriceMinorUnits => integer()();

  IntColumn get lineTotalMinorUnits => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
