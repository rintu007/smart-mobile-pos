import 'package:drift/drift.dart';

import 'sales.dart';

/// M0 is cash-only (backlog.md item 6) — the `method` CHECK still allows the
/// full server enum since it costs nothing extra, but only 'cash' rows are
/// written until Split Payment (M2) exists.
class SalePayments extends Table {
  TextColumn get id => text()();

  TextColumn get saleId => text().references(Sales, #id)();

  TextColumn get method =>
      text().customConstraint("NOT NULL CHECK (method IN ('cash','card','other'))")();

  /// `integer()`, not `int64()` — see products.dart's comment on
  /// `priceMinorUnits`.
  IntColumn get amountMinorUnits => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
