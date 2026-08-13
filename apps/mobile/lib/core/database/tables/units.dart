import 'package:drift/drift.dart';

/// Local read cache of a tenant's units — added Sprint 20 (backlog.md item
/// 4). Same deviation from schema-local.md's "full local read/write copy"
/// classification as `Categories`, for the same reason: no `unit.create`
/// sync-push operation type exists yet, so creation calls the server
/// directly and this table is only ever written to after that succeeds.
@DataClassName('Unit')
class Units extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get symbol => text()();

  BoolColumn get allowsFractional =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
