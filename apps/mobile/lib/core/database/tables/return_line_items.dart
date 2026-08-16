import 'package:drift/drift.dart';

import 'returns.dart';

/// Mirrors the server's `return_line_items` table (docs/modules/returns/
/// specification.md §3). Drift's generated row class (`ReturnLineItem`)
/// collides with this feature's own domain entity of the same name —
/// resolved the same way `Customer`/`Category`/`Unit`/`Product` already
/// were, a `hide ReturnLineItem` import wherever both are needed in one
/// file.
class ReturnLineItems extends Table {
  /// Server-generated on the server row; mirrored as-is locally (no
  /// client-facing idempotency need of its own, matching the server's own
  /// design — identified only through its parent return).
  TextColumn get id => text()();

  TextColumn get returnId => text().references(Returns, #id)();

  TextColumn get originalSaleLineItemId => text()();

  IntColumn get quantity => integer()();

  IntColumn get refundAmountMinorUnits => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
