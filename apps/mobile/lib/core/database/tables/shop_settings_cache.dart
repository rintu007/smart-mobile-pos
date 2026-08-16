import 'package:drift/drift.dart';

/// Added Sprint 37 (backlog.md M4 item 2) — a one-row local cache, matching
/// `StoreContext`'s own established `'current'`-id convention. Deliberately
/// not a full `shop_settings` mirror (no `tax_mode`/`pricing_mode`/etc.) —
/// only the two fields Reports actually needs: the low-stock threshold
/// (pulled from the server, Sprint 37's own new `shop_settings` sync entity
/// type) and `canViewReports` (**not** pulled from anywhere — written
/// directly by `SyncRepository` after probing an existing Manager/Owner-only
/// endpoint, docs/modules/reports/specification.md §1's third gap). Extended
/// when Settings' mobile UI (M4 item 3) needs the rest.
class ShopSettingsCache extends Table {
  TextColumn get id => text()();

  IntColumn get lowStockThresholdQuantity => integer().nullable()();

  BoolColumn get canViewReports => boolean().withDefault(const Constant(false))();

  DateTimeColumn get fetchedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
