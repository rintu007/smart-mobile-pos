import 'package:drift/drift.dart';

/// Local-only, no server equivalent yet — `client_device_id` normally lives
/// in the not-yet-built `devices` table (Authentication's device-registration
/// slice), per identifiers.md §2. This table holds just enough of that
/// concept locally to feed ADR-0008's provisional invoice numbering: a
/// single row (`id = 'current'`), generated once per install and never
/// derived from a hardware identifier (identifiers.md §4's edge case — a
/// reinstalled app must get a fresh numbering namespace, not silently reuse
/// one).
class DeviceIdentity extends Table {
  TextColumn get id => text()();

  TextColumn get shortId => text()();

  @override
  Set<Column> get primaryKey => {id};
}
