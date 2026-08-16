import 'package:drift/drift.dart';

/// Added Sprint 36 (backlog.md M4 item 1) — persists the last-seen pull
/// cursor per `entity_type`, so `stock_movements`/`sales` (unlike
/// `products`, an intentionally-unchanged, near-static catalogue —
/// docs/modules/sync-engine/specification.md §2) resume from where the
/// previous sync cycle left off instead of re-pulling the device's entire
/// transaction history on every sync. One row per entity type; `cursor` is
/// null only for an entity type never yet synced.
class SyncCursors extends Table {
  TextColumn get entityType => text()();

  TextColumn get cursor => text().nullable()();

  @override
  Set<Column> get primaryKey => {entityType};
}
