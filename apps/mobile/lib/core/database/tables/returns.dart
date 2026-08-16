import 'package:drift/drift.dart';

/// Local read cache + genuinely offline-writable return records — added
/// Sprint 34 (backlog.md M3 item 4). Mirrors the server's `returns` table
/// (docs/modules/returns/specification.md §3) exactly: `id` is the sole
/// idempotency key, no separate `client_operation_id` column, matching the
/// server's own dated correction. `create`/`approve`/`reject` are all real
/// `outbound_queue` operation types (docs/modules/returns/specification.md
/// §1b) — the same local-write-plus-enqueue shape `Customers`/`Sales`
/// already established, not a read-only cache.
///
/// No FK enforced to the local `Sales` table: the original sale a return
/// references may legitimately not exist locally at all (it was located via
/// a live network fetch, per specification.md §1b) — the same softer,
/// unenforced-FK precedent `Sales.customerId` already established.
///
/// Domain entities are named `ReturnSummary`/`ReturnDetail` (not a bare
/// `Return`) specifically to sidestep Drift's generated-row-class collision
/// with this table's own name — see `return_line_items.dart`'s own
/// docstring for the one place that collision couldn't be avoided the same
/// way.
class Returns extends Table {
  /// Client-generated UUID, per ADR-0007 — matches the server row.
  TextColumn get id => text()();

  TextColumn get originalSaleId => text()();

  /// 'pending_approval' / 'completed' / 'rejected' — matches the server's
  /// own reachable subset (returns/specification.md §1, correction 3).
  TextColumn get status => text()();

  IntColumn get refundTotalMinorUnits => integer()();

  TextColumn get approvedBy => text().nullable()();

  DateTimeColumn get completedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
