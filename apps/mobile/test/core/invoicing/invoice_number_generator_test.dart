import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart';
import 'package:mobile/core/invoicing/invoice_number_generator.dart';

void main() {
  late AppDatabase db;
  late InvoiceNumberGenerator generator;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    generator = InvoiceNumberGenerator(db);
  });

  tearDown(() => db.close());

  test('generates a number shaped {device_short_id}-{financial_year}-{sequence}', () async {
    final number = await generator.next(now: DateTime(2026, 8, 2));

    final parts = number.split('-');
    expect(parts, hasLength(3));
    expect(parts[0], hasLength(6));
    expect(parts[1], '2026');
    expect(parts[2], '000001');
  });

  test('the device short id is generated once and stays stable across calls', () async {
    final first = await generator.next(now: DateTime(2026, 8, 2));
    final second = await generator.next(now: DateTime(2026, 8, 3));

    expect(first.split('-')[0], second.split('-')[0]);

    final deviceRows = await db.select(db.deviceIdentity).get();
    expect(deviceRows, hasLength(1));
  });

  test('the sequence increments within the same financial year', () async {
    final first = await generator.next(now: DateTime(2026, 8, 2));
    final second = await generator.next(now: DateTime(2026, 8, 3));
    final third = await generator.next(now: DateTime(2027, 3, 31));

    expect(first.split('-')[2], '000001');
    expect(second.split('-')[2], '000002');
    expect(third.split('-')[2], '000003');
  });

  test('the financial year rolls over on April 1', () async {
    final beforeRollover = await generator.next(now: DateTime(2027, 3, 31));
    final afterRollover = await generator.next(now: DateTime(2027, 4, 1));

    expect(beforeRollover.split('-')[1], '2026');
    expect(afterRollover.split('-')[1], '2027');
    // A new financial year starts its own sequence fresh at 1, not
    // continuing the prior year's count — identifiers.md §3.
    expect(afterRollover.split('-')[2], '000001');
  });
}
