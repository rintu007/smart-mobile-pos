import 'package:drift/drift.dart';

/// Sprint 20 (backlog.md item 4) added `category_id`/`unit_id`, both nullable
/// — mirroring the server's own Sprint 19 decision (`products/specification.md
/// §1`) to keep them optional rather than required: existing local rows from
/// before that migration had neither, and the server itself still accepts
/// either omitted. `/catalogue/add`'s own form requires a selection for any
/// *new* product going forward (backlog item 4's own wording), but that's a
/// UI-level rule, not a schema one.
///
/// Sprint 21 (backlog.md item 5) adds `sku`/`barcode`, both nullable — the
/// till's barcode-scan lookup (FR-034/FR-036, "Fully offline") reads this
/// column directly from the local cache, never the network, so it must be
/// populated by the pull-sync this sprint also fixed to actually carry it
/// down. `hsn_sac_code`/`deactivated_at` remain out of scope — no mobile
/// feature needs either yet.
///
/// No `tenant_id` — a device holds exactly one tenant's data in V1
/// (schema-local.md's opening assumption).
class Products extends Table {
  /// Client-generated UUID, per ADR-0007 — matches the eventual server row.
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get categoryId => text().nullable()();

  TextColumn get unitId => text().nullable()();

  TextColumn get sku => text().nullable()();

  TextColumn get barcode => text().nullable()();

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
