import 'package:drift/drift.dart';

/// Added Sprint 37 (backlog.md M4 item 2) — a one-row local cache, matching
/// `StoreContext`'s own established `'current'`-id convention. Deliberately
/// not a full `shop_settings` mirror (no `tax_mode`/`pricing_mode`/etc.) —
/// only the fields an offline-capable feature actually needs: the low-stock
/// threshold (Reports), `canViewReports` (**not** pulled from anywhere —
/// written directly by `SyncRepository` after probing an existing
/// Manager/Owner-only endpoint, docs/modules/reports/specification.md §1's
/// third gap), and `footerMessage` (Sprint 39, backlog.md M4 item 4 — the
/// one field `ReceiptFormatter` needs to print offline, per FR-077's own
/// "Fully offline" classification; see `settings_repository.dart`'s
/// docstring for why the *editable* `/settings` screen itself still has no
/// cache while this one narrow, read-only, print-time value does).
class ShopSettingsCache extends Table {
  TextColumn get id => text()();

  IntColumn get lowStockThresholdQuantity => integer().nullable()();

  BoolColumn get canViewReports => boolean().withDefault(const Constant(false))();

  TextColumn get footerMessage => text().nullable()();

  DateTimeColumn get fetchedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
