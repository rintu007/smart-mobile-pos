import 'package:drift/drift.dart';

/// Local read cache + genuinely offline-writable customer records — added
/// Sprint 32 (backlog.md M3 item 2). Unlike Categories/Units (online-only
/// creation, no sync-push type exists), `customer.create` is a real
/// `outbound_queue` operation type (docs/modules/customers/specification.md
/// §1a) — `DriftCustomerRepository.createCustomer` writes here and enqueues
/// in the same transaction, the same shape `Products`/`DriftProductRepository`
/// already established, not Categories' direct-online-call shape.
///
/// Reads are direct-fetch-and-cache (`refreshFromServer`), not sync-pulled —
/// a deliberate, named scope boundary (customers/specification.md §1a): a
/// full bidirectional `GET /sync/pull?entity_type=customers` cursor
/// mechanism is real, undiscussed scope this single new read path doesn't
/// need yet.
///
/// Drift's generated row class is also named `Customer` — the same
/// collision `Category`/`Unit`/`Product` already have with their own domain
/// entities, handled the same way (`hide Customer` on this file's import
/// wherever both are needed in the same file).
class Customers extends Table {
  /// Client-generated UUID, per ADR-0007 — matches the server row.
  TextColumn get id => text()();

  TextColumn get name => text().nullable()();

  TextColumn get phone => text().nullable()();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
