import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart';
import 'package:mobile/core/database/device_identity_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('generates and persists both a shortId and a clientDeviceId on first call', () async {
    final record = await ensureDeviceIdentity(db);

    expect(record.shortId, hasLength(6));
    expect(record.clientDeviceId, isNotEmpty);

    final rows = await db.select(db.deviceIdentity).get();
    expect(rows, hasLength(1));
    expect(rows.single.shortId, record.shortId);
    expect(rows.single.clientDeviceId, record.clientDeviceId);
  });

  test('returns the same identity on a second call — stable across calls, not regenerated', () async {
    final first = await ensureDeviceIdentity(db);
    final second = await ensureDeviceIdentity(db);

    expect(second.shortId, first.shortId);
    expect(second.clientDeviceId, first.clientDeviceId);

    final rows = await db.select(db.deviceIdentity).get();
    expect(rows, hasLength(1));
  });

  test(
    'backfills clientDeviceId in place for a pre-existing row that only has a shortId '
    '(a device that generated its shortId before this column existed, Sprint 09 vs. Sprint 56)',
    () async {
      await db
          .into(db.deviceIdentity)
          .insert(
            DeviceIdentityCompanion.insert(id: 'current', shortId: 'ABC123'),
          );

      final record = await ensureDeviceIdentity(db);

      expect(record.shortId, 'ABC123');
      expect(record.clientDeviceId, isNotEmpty);

      final rows = await db.select(db.deviceIdentity).get();
      expect(rows, hasLength(1));
      expect(rows.single.clientDeviceId, record.clientDeviceId);
    },
  );
}
