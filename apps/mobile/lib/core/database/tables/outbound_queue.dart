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

  /// 'queued' / 'synced' / 'failed_retrying' / 'rejected' in practice.
  /// state-machines.md's Sync Item diagram also names a transitional
  /// 'syncing' value (written on "attempt begins," before a server
  /// response is known) — `SyncRepository` never writes it (found Sprint
  /// 50, writing the first test to actually exercise an interrupted push):
  /// a row selected for the current attempt stays 'queued'/'failed_retrying'
  /// for the whole network call and is updated only once a real per-operation
  /// result is known, so an interrupted attempt leaves the row untouched
  /// rather than stuck in a distinct in-flight state. See
  /// state-machines.md's own dated correction for why this is still safe.
  TextColumn get status => text().withDefault(const Constant('queued'))();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  DateTimeColumn get lastAttemptedAt => dateTime().nullable()();

  /// Populated only when status = 'rejected' — surfaced to the user per BR-053.
  TextColumn get rejectionReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {clientOperationId};
}
