import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bluetooth_printer_repository.dart';
import '../providers/receipt_printing_providers.dart';
import '../widgets/printer_picker_dialog.dart';

/// `/settings/printer`, per route-map.md (Sprint 39, backlog.md M4 item 4)
/// — FR-077: "A Bluetooth printer can be paired and test-printed from
/// settings, independent of any sale." Reachable by every role (permission-matrix.md
/// — "operational, not business-sensitive"), no server call at all: pairing
/// reuses the phone's own OS-level Bluetooth pairing (same as the existing
/// per-sale picker, `showPrinterPickerDialog`) and just remembers the pick
/// locally (`PairedPrinterCache`) so `/sales-history/:id`'s own print action
/// no longer has to ask every time.
class PrinterSettingsScreen extends ConsumerWidget {
  const PrinterSettingsScreen({super.key});

  Future<void> _choosePrinter(BuildContext context, WidgetRef ref) async {
    final printer = await showPrinterPickerDialog(context);
    if (printer == null) return;
    await ref.read(pairedPrinterRepositoryProvider).setPairedPrinter(printer);
    ref.invalidate(pairedPrinterProvider);
  }

  Future<void> _testPrint(
    BuildContext context,
    WidgetRef ref,
    PairedPrinter printer,
  ) async {
    final shopName = await ref.read(shopNameProvider.future);
    final footerMessage = await ref.read(receiptFooterMessageProvider.future);
    await ref
        .read(receiptPrintControllerProvider.notifier)
        .printTest(
          shopName: shopName,
          macAddress: printer.macAddress,
          footerMessage: footerMessage,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paired = ref.watch(pairedPrinterProvider);
    final printState = ref.watch(receiptPrintControllerProvider);

    ref.listen(receiptPrintControllerProvider, (previous, next) {
      next.when(
        data: (success) {
          if (success == null) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Test receipt sent to printer.'
                    : 'Printer did not accept the test receipt.',
                key: const Key('printer_test_print_result'),
              ),
            ),
          );
        },
        error: (error, stack) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not connect to printer: $error')),
        ),
        loading: () {},
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Pair printer')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              paired.when(
                data: (printer) => printer == null
                    ? const Text(
                        'No printer paired yet.',
                        key: Key('printer_settings_none_paired'),
                      )
                    : ListTile(
                        key: const Key('printer_settings_paired'),
                        leading: const Icon(Icons.print),
                        title: Text(printer.name),
                        subtitle: Text(printer.macAddress),
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    const Text('Could not load the paired printer.'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('printer_settings_choose_button'),
                onPressed: () => _choosePrinter(context, ref),
                child: const Text('Choose printer'),
              ),
              const SizedBox(height: 16),
              paired.maybeWhen(
                data: (printer) => printer == null
                    ? const SizedBox.shrink()
                    : SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          key: const Key('printer_settings_test_print_button'),
                          onPressed: printState.isLoading
                              ? null
                              : () => _testPrint(context, ref, printer),
                          child: printState.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Test print'),
                        ),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
