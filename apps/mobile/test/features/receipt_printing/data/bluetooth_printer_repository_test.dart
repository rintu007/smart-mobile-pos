import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/receipt_printing/data/bluetooth_printer_repository.dart';

void main() {
  group('listPairedPrinters', () {
    test('returns an empty list when Bluetooth permission is not granted', () async {
      final repo = BluetoothPrinterRepository(
        isPermissionGranted: () async => false,
        isBluetoothEnabled: () async => true,
        pairedDevices: () async => [const PairedPrinter(name: 'X', macAddress: '00:00')],
        connect: (_) async => true,
        writeBytes: (_) async => true,
        disconnect: () async => true,
      );

      expect(await repo.listPairedPrinters(), isEmpty);
    });

    test('returns an empty list when Bluetooth is off', () async {
      final repo = BluetoothPrinterRepository(
        isPermissionGranted: () async => true,
        isBluetoothEnabled: () async => false,
        pairedDevices: () async => [const PairedPrinter(name: 'X', macAddress: '00:00')],
        connect: (_) async => true,
        writeBytes: (_) async => true,
        disconnect: () async => true,
      );

      expect(await repo.listPairedPrinters(), isEmpty);
    });

    test('returns paired devices when permission is granted and Bluetooth is on', () async {
      final repo = BluetoothPrinterRepository(
        isPermissionGranted: () async => true,
        isBluetoothEnabled: () async => true,
        pairedDevices: () async => [const PairedPrinter(name: 'X', macAddress: '00:00')],
        connect: (_) async => true,
        writeBytes: (_) async => true,
        disconnect: () async => true,
      );

      final printers = await repo.listPairedPrinters();
      expect(printers, hasLength(1));
      expect(printers.single.name, 'X');
    });
  });

  group('printBytes', () {
    test('returns false and never attempts a write when connect fails', () async {
      var writeCalled = false;
      final repo = BluetoothPrinterRepository(
        isPermissionGranted: () async => true,
        isBluetoothEnabled: () async => true,
        pairedDevices: () async => const [],
        connect: (_) async => false,
        writeBytes: (_) async {
          writeCalled = true;
          return true;
        },
        disconnect: () async => true,
      );

      final result = await repo.printBytes(macAddress: '00:00', bytes: const [1, 2, 3]);

      expect(result, false);
      expect(writeCalled, false);
    });

    test('disconnects even when the write fails', () async {
      var disconnectCalled = false;
      final repo = BluetoothPrinterRepository(
        isPermissionGranted: () async => true,
        isBluetoothEnabled: () async => true,
        pairedDevices: () async => const [],
        connect: (_) async => true,
        writeBytes: (_) async => false,
        disconnect: () async {
          disconnectCalled = true;
          return true;
        },
      );

      final result = await repo.printBytes(macAddress: '00:00', bytes: const [1, 2, 3]);

      expect(result, false);
      expect(disconnectCalled, true);
    });

    test('disconnects even when the write throws', () async {
      var disconnectCalled = false;
      final repo = BluetoothPrinterRepository(
        isPermissionGranted: () async => true,
        isBluetoothEnabled: () async => true,
        pairedDevices: () async => const [],
        connect: (_) async => true,
        writeBytes: (_) async => throw StateError('boom'),
        disconnect: () async {
          disconnectCalled = true;
          return true;
        },
      );

      await expectLater(
        repo.printBytes(macAddress: '00:00', bytes: const [1, 2, 3]),
        throwsA(isA<StateError>()),
      );
      expect(disconnectCalled, true);
    });

    test('returns true when connect and write both succeed', () async {
      final repo = BluetoothPrinterRepository(
        isPermissionGranted: () async => true,
        isBluetoothEnabled: () async => true,
        pairedDevices: () async => const [],
        connect: (_) async => true,
        writeBytes: (_) async => true,
        disconnect: () async => true,
      );

      final result = await repo.printBytes(macAddress: '00:00', bytes: const [1, 2, 3]);

      expect(result, true);
    });
  });
}
