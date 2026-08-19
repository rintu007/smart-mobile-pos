import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';

/// Sprint 56 — the single `device_identity` row's two identifiers, generated together the first
/// time either is needed: `shortId` (ADR-0008's local provisional invoice numbering, Sprint 09)
/// and `clientDeviceId` (the real identifier the server's `devices` table keys on, Sprint 55).
/// Both used to be generated separately (`InvoiceNumberGenerator`'s own private
/// `_ensureDeviceShortId`) since `clientDeviceId` had nothing server-side to register against yet
/// — unified here now that it does, rather than two independent "is there a row yet?" checks
/// racing each other.
class DeviceIdentityRecord {
  const DeviceIdentityRecord({required this.shortId, required this.clientDeviceId});

  final String shortId;
  final String clientDeviceId;
}

const _deviceRowId = 'current';
const _shortIdAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const _shortIdLength = 6;

/// Never derived from a stable hardware identifier (identifiers.md §4) — both fields are
/// generated fresh, locally, and persisted the first time this is called. A pre-existing row from
/// before `clientDeviceId` existed as a column (any device that already generated a `shortId`
/// under Sprint 09) is backfilled in place, keeping its original `shortId` rather than starting a
/// fresh invoice-numbering namespace it doesn't need to.
Future<DeviceIdentityRecord> ensureDeviceIdentity(AppDatabase db) async {
  final existing = await (db.select(
    db.deviceIdentity,
  )..where((t) => t.id.equals(_deviceRowId))).getSingleOrNull();

  if (existing != null && existing.clientDeviceId != null) {
    return DeviceIdentityRecord(shortId: existing.shortId, clientDeviceId: existing.clientDeviceId!);
  }

  if (existing == null) {
    final shortId = _generateShortId();
    final generatedClientDeviceId = const Uuid().v4();
    await db
        .into(db.deviceIdentity)
        .insert(
          DeviceIdentityCompanion.insert(
            id: _deviceRowId,
            shortId: shortId,
            clientDeviceId: Value(generatedClientDeviceId),
          ),
        );
    return DeviceIdentityRecord(shortId: shortId, clientDeviceId: generatedClientDeviceId);
  }

  final generatedClientDeviceId = const Uuid().v4();
  await (db.update(
    db.deviceIdentity,
  )..where((t) => t.id.equals(_deviceRowId))).write(
    DeviceIdentityCompanion(clientDeviceId: Value(generatedClientDeviceId)),
  );
  return DeviceIdentityRecord(shortId: existing.shortId, clientDeviceId: generatedClientDeviceId);
}

String _generateShortId() {
  final random = Random.secure();
  return List.generate(
    _shortIdLength,
    (_) => _shortIdAlphabet[random.nextInt(_shortIdAlphabet.length)],
  ).join();
}
