import 'package:drift/drift.dart';

/// The durable operation queue — the local realisation of the Sync Item state
/// machine (docs/06-workflows/state-machines.md#sync-item). Full V1 shape,
/// per docs/07-database/schema-local.md — no M0-minimal subset here, unlike
/// products/sales/stock_movements, since this table's shape doesn't grow with
/// later milestones.
class OutboundQueue extends Table {
  /// Matches the eventual server row's own id, per ADR-0007 (client-generated
  /// UUID primary keys) — not a separate queue-entry id.
  TextColumn get clientOperationId => text()();

  /// e.g. 'sale', 'stock_movement', 'return'.
  TextColumn get entityType => text()();

  /// The full operation, serialised as JSON.
  TextColumn get payload => text()();

  /// 'queued' / 'syncing' / 'synced' / 'failed_retrying' / 'rejected' —
  /// mirrors state-machines.md's Sync Item exactly.
  TextColumn get status => text().withDefault(const Constant('queued'))();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  DateTimeColumn get lastAttemptedAt => dateTime().nullable()();

  /// Populated only when status = 'rejected' — surfaced to the user per BR-053.
  TextColumn get rejectionReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {clientOperationId};
}
