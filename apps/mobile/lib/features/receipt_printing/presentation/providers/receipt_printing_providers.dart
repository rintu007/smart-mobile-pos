import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../../../app/providers.dart';
import '../../../pos/domain/entities/sale_detail.dart';
import '../../data/bluetooth_printer_repository.dart';
import '../../data/esc_pos_receipt_encoder.dart';
import '../../data/paired_printer_repository.dart';
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

/// Added Sprint 39 (backlog.md M4 item 4) — `PairedPrinterCache`'s own
/// repository wrapper, same DI-via-constructor shape every other Drift
/// repository in this codebase uses.
final pairedPrinterRepositoryProvider = Provider<PairedPrinterRepository>((ref) {
  return PairedPrinterRepository(ref.watch(appDatabaseProvider));
});

/// The currently-paired printer, per `/settings/printer` — `autoDispose`
/// since it's only watched by the two screens that need it (printer
/// pairing and sale-detail's print action), not the always-alive
/// home-screen graph.
final pairedPrinterProvider = FutureProvider.autoDispose<PairedPrinter?>((ref) {
  return ref.watch(pairedPrinterRepositoryProvider).getPairedPrinter();
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

/// The receipt footer message, per `/settings/receipt-template` — read from
/// `ShopSettingsCache` (Sprint 39, backlog.md M4 item 4), **not** a live
/// `GET /settings` call, so printing stays fully offline per FR-077/FR-078's
/// own classification. `null` (never configured, or never synced yet) falls
/// through to `ReceiptFormatter`'s own hard-coded default.
final receiptFooterMessageProvider = FutureProvider.autoDispose<String?>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final row = await (db.select(
    db.shopSettingsCache,
  )..where((t) => t.id.equals('current'))).getSingleOrNull();
  return row?.footerMessage;
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
    String? footerMessage,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final document = ref
          .read(receiptFormatterProvider)
          .build(
            sale: sale,
            shopName: shopName,
            footerMessage: footerMessage ?? 'Thank you, visit again!',
          );
      final bytes = await ref.read(escPosReceiptEncoderProvider).encode(document);
      return ref
          .read(bluetoothPrinterRepositoryProvider)
          .printBytes(macAddress: macAddress, bytes: bytes);
    });
  }

  /// `/settings/printer`'s "Test print" button (Sprint 39, backlog.md M4
  /// item 4) — same result semantics as [printReceipt] above, built from
  /// [ReceiptFormatter.buildTest] instead of a real sale.
  Future<void> printTest({
    required String shopName,
    required String macAddress,
    String? footerMessage,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final document = ref
          .read(receiptFormatterProvider)
          .buildTest(
            shopName: shopName,
            footerMessage: footerMessage ?? 'Thank you, visit again!',
          );
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
