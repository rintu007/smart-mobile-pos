/// One paired Bluetooth device, printer-agnostic — the repository doesn't
/// know which paired device is actually a printer (neither does
/// `print_bluetooth_thermal`, per its own API); the picker UI just lists
/// every paired device and lets the Cashier/Manager choose, same reasoning
/// a phone's own Bluetooth settings screen works.
class PairedPrinter {
  const PairedPrinter({required this.name, required this.macAddress});

  final String name;
  final String macAddress;
}

/// Wraps `print_bluetooth_thermal`'s static API behind an injectable
/// interface — same DI reasoning `StoreContextRepository`/`SyncRepository`
/// already established, so tests can fake the plugin call without a
/// platform channel (which doesn't exist at all in a plain `flutter test`
/// run — there is no real Bluetooth adapter in CI or this dev machine).
/// **Not live-verified against a physical printer this sprint** —
/// per manual-test-scripts.md MTS-01, that requires real Bluetooth ESC/POS
/// hardware, a founder action, not an engineering one (the same category as
/// device-matrix.md §3's physical reference device).
class BluetoothPrinterRepository {
  const BluetoothPrinterRepository({
    required this.isPermissionGranted,
    required this.isBluetoothEnabled,
    required this.pairedDevices,
    required this.connect,
    required this.writeBytes,
    required this.disconnect,
  });

  final Future<bool> Function() isPermissionGranted;
  final Future<bool> Function() isBluetoothEnabled;
  final Future<List<PairedPrinter>> Function() pairedDevices;
  final Future<bool> Function(String macAddress) connect;
  final Future<bool> Function(List<int> bytes) writeBytes;
  final Future<bool> Function() disconnect;

  Future<List<PairedPrinter>> listPairedPrinters() async {
    if (!await isPermissionGranted() || !await isBluetoothEnabled()) {
      return const [];
    }
    return pairedDevices();
  }

  /// Connects, writes [bytes], then always disconnects — even on a write
  /// failure — so a failed print never leaves the Bluetooth radio holding a
  /// stale connection open (per BR-034/BR-035: a printing failure must never
  /// cascade into anything else going wrong).
  Future<bool> printBytes({required String macAddress, required List<int> bytes}) async {
    final connected = await connect(macAddress);
    if (!connected) return false;

    try {
      return await writeBytes(bytes);
    } finally {
      await disconnect();
    }
  }
}
