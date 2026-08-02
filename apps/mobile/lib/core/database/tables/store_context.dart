import 'package:drift/drift.dart';

/// A one-row local cache of which store this device belongs to — not an
/// entity that syncs (never written to `outbound_queue`), just a read
/// cache refreshed from `GET /api/v1/stores` after sign-in, per
/// schema-local.md's `shop_settings` precedent (a local read cache, not a
/// queued write). Added Sprint 08 as the till screen's prerequisite: a sale
/// cannot be created without knowing its `store_id`, and nothing before
/// this sprint gave the device one.
class StoreContext extends Table {
  /// Always the literal string `'current'` — this table only ever holds one
  /// row, since a device belongs to exactly one store in V1 (ADR-0003).
  TextColumn get id => text()();

  TextColumn get storeId => text()();

  TextColumn get storeName => text()();

  DateTimeColumn get fetchedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
