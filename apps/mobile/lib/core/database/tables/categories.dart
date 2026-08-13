import 'package:drift/drift.dart';

/// Local read cache of a tenant's categories — added Sprint 20 (backlog.md
/// item 4). Deviates from schema-local.md's "full local read/write copy"
/// classification in one way, named in `drift_category_repository.dart`'s
/// own docstring: creation calls the server directly rather than going
/// through `outbound_queue`, since the sync engine (sync-api.md) has no
/// `category.create` push operation type yet — only `product.create`/
/// `sale.create` exist. This table is written to only after the server has
/// already accepted the row, so it never holds an unsynced pending write.
@DataClassName('Category')
class Categories extends Table {
  /// Client-generated UUID, per ADR-0007 — matches the server row.
  TextColumn get id => text()();

  TextColumn get name => text()();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
