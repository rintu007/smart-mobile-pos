import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart';
import 'package:mobile/features/receipt_printing/data/bluetooth_printer_repository.dart';
import 'package:mobile/features/receipt_printing/data/paired_printer_repository.dart';

void main() {
  late AppDatabase db;
  late PairedPrinterRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PairedPrinterRepository(db);
  });

  test('returns null when nothing has ever been paired', () async {
    expect(await repo.getPairedPrinter(), isNull);
  });

  test('persists and returns the paired printer', () async {
    await repo.setPairedPrinter(const PairedPrinter(name: 'Epson TM-T20', macAddress: '00:11:22'));

    final printer = await repo.getPairedPrinter();
    expect(printer?.name, 'Epson TM-T20');
    expect(printer?.macAddress, '00:11:22');
  });

  test('a second pairing replaces the first, single-row-cache style', () async {
    await repo.setPairedPrinter(const PairedPrinter(name: 'A', macAddress: '00:00:01'));
    await repo.setPairedPrinter(const PairedPrinter(name: 'B', macAddress: '00:00:02'));

    final printer = await repo.getPairedPrinter();
    expect(printer?.macAddress, '00:00:02');
  });
}
