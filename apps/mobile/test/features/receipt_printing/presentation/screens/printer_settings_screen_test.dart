import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/database/database.dart';
import 'package:mobile/features/receipt_printing/data/bluetooth_printer_repository.dart';
import 'package:mobile/features/receipt_printing/data/esc_pos_receipt_encoder.dart';
import 'package:mobile/features/receipt_printing/domain/entities/receipt_document.dart';
import 'package:mobile/features/receipt_printing/presentation/providers/receipt_printing_providers.dart';
import 'package:mobile/features/receipt_printing/presentation/screens/printer_settings_screen.dart';

/// `EscPosReceiptEncoder.encode` loads `esc_pos_utils_plus`'s bundled
/// `capabilities.json` via `rootBundle` — a real platform-channel call that
/// deadlocks inside `testWidgets()`'s fake-async zone (unlike a plain
/// `test()`, see `esc_pos_receipt_encoder_test.dart`'s own comment). Faked
/// here at the screen-test level, same as `bluetoothPrinterRepositoryProvider`
/// — the encoder's own correctness is already covered by its dedicated
/// unit tests; this screen only needs to prove it calls the pipeline.
class _FakeEscPosReceiptEncoder extends EscPosReceiptEncoder {
  const _FakeEscPosReceiptEncoder();

  @override
  Future<List<int>> encode(ReceiptDocument doc) async => const [1, 2, 3];
}

Widget _wrap({required AppDatabase db, BluetoothPrinterRepository? bluetoothRepository}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      escPosReceiptEncoderProvider.overrideWithValue(const _FakeEscPosReceiptEncoder()),
      if (bluetoothRepository != null)
        bluetoothPrinterRepositoryProvider.overrideWithValue(bluetoothRepository),
    ],
    child: const MaterialApp(home: PrinterSettingsScreen()),
  );
}

void main() {
  testWidgets('shows "No printer paired yet" when nothing is cached', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await tester.pumpWidget(_wrap(db: db));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('printer_settings_none_paired')), findsOneWidget);
    expect(find.byKey(const Key('printer_settings_test_print_button')), findsNothing);
  });

  testWidgets('choosing a printer persists it and shows it, enabling test print', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final bluetoothRepository = BluetoothPrinterRepository(
      isPermissionGranted: () async => true,
      isBluetoothEnabled: () async => true,
      pairedDevices: () async => const [PairedPrinter(name: 'Epson TM-T20', macAddress: '00:11:22')],
      connect: (_) async => true,
      writeBytes: (_) async => true,
      disconnect: () async => true,
    );

    await tester.pumpWidget(_wrap(db: db, bluetoothRepository: bluetoothRepository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('printer_settings_choose_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('printer_picker_item_00:11:22')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('printer_settings_paired')), findsOneWidget);
    expect(find.text('Epson TM-T20'), findsOneWidget);
    expect(find.byKey(const Key('printer_settings_test_print_button')), findsOneWidget);

    final row = await (db.select(
      db.pairedPrinterCache,
    )..where((t) => t.id.equals('current'))).getSingle();
    expect(row.macAddress, '00:11:22');
  });

  testWidgets('tapping test print sends bytes to the already-paired printer', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.pairedPrinterCache)
        .insertOnConflictUpdate(
          PairedPrinterCacheCompanion.insert(
            id: 'current',
            macAddress: const Value('00:11:22'),
            name: const Value('Epson TM-T20'),
          ),
        );
    List<int>? sentBytes;
    final bluetoothRepository = BluetoothPrinterRepository(
      isPermissionGranted: () async => true,
      isBluetoothEnabled: () async => true,
      pairedDevices: () async => const [],
      connect: (_) async => true,
      writeBytes: (bytes) async {
        sentBytes = bytes;
        return true;
      },
      disconnect: () async => true,
    );

    await tester.pumpWidget(_wrap(db: db, bluetoothRepository: bluetoothRepository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('printer_settings_test_print_button')));
    await tester.pumpAndSettle();

    expect(sentBytes, isNotEmpty);
    expect(find.text('Test receipt sent to printer.'), findsOneWidget);
  });
}
