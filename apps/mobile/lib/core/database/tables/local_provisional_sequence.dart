import 'package:drift/drift.dart';

/// The per-device counter backing provisional invoice numbers — ADR-0008,
/// documented in schema-local.md verbatim. Keyed by financial year only (not
/// also by device — one device, one local database, per device_identity.dart)
/// so a new financial year simply has no row yet rather than needing a reset
/// job that could fail or run late (identifiers.md §3).
class LocalProvisionalSequence extends Table {
  TextColumn get financialYear => text()();

  IntColumn get nextSequence => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {financialYear};
}
