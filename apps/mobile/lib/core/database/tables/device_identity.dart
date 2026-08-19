import 'package:drift/drift.dart';

/// A single row (`id = 'current'`), generated once per install and never
/// derived from a hardware identifier (identifiers.md §4's edge case — a
/// reinstalled app must get a fresh numbering namespace, not silently reuse
/// one). `shortId` feeds ADR-0008's provisional invoice numbering.
/// `clientDeviceId` (Sprint 56) is the real identifier the server's
/// `devices` table keys on (schema-server.md, built Sprint 55) — this
/// column used to not exist at all, back when that table didn't either;
/// nullable so an upgrading device (one that already has a `shortId` row
/// from before this column existed) backfills it in place rather than
/// needing a fresh row.
class DeviceIdentity extends Table {
  TextColumn get id => text()();

  TextColumn get shortId => text()();

  TextColumn get clientDeviceId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
