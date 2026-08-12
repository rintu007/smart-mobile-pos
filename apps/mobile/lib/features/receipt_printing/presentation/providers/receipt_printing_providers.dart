import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../../app/providers.dart';
import '../../../pos/domain/entities/sale_detail.dart';
import '../../data/bluetooth_printer_repository.dart';
import '../../data/esc_pos_receipt_encoder.dart';
import '../../domain/receipt_formatter.dart';

final receiptFormatterProvider = Provider((ref) => const ReceiptFormatter());

final escPosReceiptEncoderProvider = Provider((ref) => const EscPosReceiptEncoder());

final bluetoothPrinterRepositoryProvider = Provider<BluetoothPrinterRepository>((ref) {
  return BluetoothPrinterRepository(
    isPermissionGranted: () => PrintBluetoothThermal.isPermissionBluetoothGranted,
    isBluetoothEnabled: () => PrintBluetoothThermal.bluetoothEnabled,
    pairedDevices: () async {
      final devices = await PrintBluetoothThermal.pairedBluetooths;
      return devices
          .map((d) => PairedPrinter(name: d.name, macAddress: d.macAdress))
          .toList();
    },
    connect: (mac) => PrintBluetoothThermal.connect(macPrinterAddress: mac),
    writeBytes: (bytes) => PrintBluetoothThermal.writeBytes(bytes),
    disconnect: () => PrintBluetoothThermal.disconnect,
  );
});

/// The header's shop name — `StoreContext.storeName`, cached locally since
/// Sprint 08. Falls back to a generic name if nothing has been cached yet
/// (not reachable through normal navigation, since printing is only ever
/// reached from a sale detail screen that itself required store context to
/// exist, but handled rather than assumed).
final shopNameProvider = FutureProvider<String>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final row = await (db.select(
    db.storeContext,
  )..where((t) => t.id.equals('current'))).getSingleOrNull();
  return row?.storeName ?? 'SmartPOS X';
});

/// Drives the "Print receipt" action — same `AsyncNotifier` shape as
/// `SyncController`/`CompleteSaleController`. `true` means the printer
/// reported success; `false` means it connected but the write failed;
/// an `AsyncError` means connecting itself failed (printer off, out of
/// range, Bluetooth disabled).
class ReceiptPrintController extends AsyncNotifier<bool?> {
  @override
  FutureOr<bool?> build() => null;

  Future<void> printReceipt({
    required SaleDetail sale,
    required String shopName,
    required String macAddress,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final document = ref.read(receiptFormatterProvider).build(sale: sale, shopName: shopName);
      final bytes = await ref.read(escPosReceiptEncoderProvider).encode(document);
      return ref
          .read(bluetoothPrinterRepositoryProvider)
          .printBytes(macAddress: macAddress, bytes: bytes);
    });
  }
}

final receiptPrintControllerProvider = AsyncNotifierProvider<ReceiptPrintController, bool?>(
  ReceiptPrintController.new,
);
