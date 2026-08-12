import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bluetooth_printer_repository.dart';
import '../providers/receipt_printing_providers.dart';

/// Lists every paired Bluetooth device and returns the one the user taps —
/// deliberately not filtered to "printers only" (see
/// `BluetoothPrinterRepository`'s own docstring: neither this app nor the
/// underlying plugin can tell a printer from any other paired device).
/// Returns `null` if dismissed without a selection.
Future<PairedPrinter?> showPrinterPickerDialog(BuildContext context) {
  return showDialog<PairedPrinter>(
    context: context,
    builder: (context) => const _PrinterPickerDialog(),
  );
}

class _PrinterPickerDialog extends ConsumerWidget {
  const _PrinterPickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printersFuture = ref.watch(bluetoothPrinterRepositoryProvider).listPairedPrinters();

    return AlertDialog(
      title: const Text('Select a printer'),
      content: FutureBuilder<List<PairedPrinter>>(
        future: printersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final printers = snapshot.data ?? const [];
          if (printers.isEmpty) {
            return const Text(
              'No paired Bluetooth devices found. Pair your printer in the '
              "phone's Bluetooth settings first, and make sure Bluetooth is on.",
              key: Key('printer_picker_empty'),
            );
          }
          return SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: printers.length,
              itemBuilder: (context, index) {
                final printer = printers[index];
                return ListTile(
                  key: Key('printer_picker_item_${printer.macAddress}'),
                  title: Text(printer.name),
                  subtitle: Text(printer.macAddress),
                  onTap: () => Navigator.of(context).pop(printer),
                );
              },
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
