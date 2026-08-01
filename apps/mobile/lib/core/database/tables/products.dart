import 'package:drift/drift.dart';

/// M0-minimal slice of docs/07-database/schema-server.md's `products` table,
/// matching backlog.md item 5's explicit scope ("minimal: name, price only —
/// no barcode/category yet"). `category_id`/`unit_id`/`sku`/`barcode`/
/// `hsn_sac_code`/`deactivated_at` are real columns in the full V1 design but
/// belong to features not yet built (Categories/Units, barcode scan) — added
/// here only once the sprint that builds them actually needs them, per this
/// project's standing rule against padding scope ahead of the backlog.
///
/// No `tenant_id` — a device holds exactly one tenant's data in V1
/// (schema-local.md's opening assumption).
class Products extends Table {
  /// Client-generated UUID, per ADR-0007 — matches the eventual server row.
  TextColumn get id => text()();

  TextColumn get name => text()();

  /// Minor units, per ADR-0006 (money as integer, never floating point).
  /// `integer()` (not `int64()`/`BigInt`) — this app is Android-only for V1
  /// (no web target), so plain 64-bit-safe Dart `int` is both sufficient and
  /// far more ergonomic than `BigInt` arithmetic throughout the till/catalogue
  /// feature code that will consume this column.
  IntColumn get priceMinorUnits => integer()();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
