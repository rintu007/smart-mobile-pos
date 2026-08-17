import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../pos/domain/entities/sale_detail.dart';
import '../../../receipt_printing/presentation/providers/receipt_printing_providers.dart';
import '../../../receipt_printing/presentation/widgets/printer_picker_dialog.dart';
import '../providers/sales_history_providers.dart';

String _formatTimestamp(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// `/sales-history/:id`, per route-map.md — built Sprint 10.
class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  /// Prefers the printer paired via `/settings/printer` (Sprint 39,
  /// backlog.md M4 item 4) — falls back to the ad-hoc picker only when
  /// nothing is paired yet, and remembers whatever's picked there too, so
  /// this dialog stops appearing on every future print once a choice has
  /// been made once, from either screen.
  Future<void> _printReceipt(BuildContext context, WidgetRef ref, SaleDetail sale) async {
    var printer = await ref.read(pairedPrinterRepositoryProvider).getPairedPrinter();
    if (printer == null) {
      if (!context.mounted) return;
      printer = await showPrinterPickerDialog(context);
      if (printer == null) return;
      await ref.read(pairedPrinterRepositoryProvider).setPairedPrinter(printer);
    }
    if (!context.mounted) return;

    final shopName = await ref.read(shopNameProvider.future);
    final footerMessage = await ref.read(receiptFooterMessageProvider.future);
    await ref
        .read(receiptPrintControllerProvider.notifier)
        .printReceipt(
          sale: sale,
          shopName: shopName,
          macAddress: printer.macAddress,
          footerMessage: footerMessage,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(saleDetailProvider(saleId));
    final printState = ref.watch(receiptPrintControllerProvider);

    ref.listen(receiptPrintControllerProvider, (previous, next) {
      next.when(
        data: (success) {
          if (success == null) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success ? 'Receipt sent to printer.' : 'Printer did not accept the receipt.',
                key: const Key('receipt_print_result'),
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
      appBar: AppBar(
        title: const Text('Sale detail'),
        actions: [
          detail.maybeWhen(
            data: (sale) => sale == null
                ? const SizedBox.shrink()
                : IconButton(
                    key: const Key('sale_detail_print_button'),
                    icon: printState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print),
                    tooltip: 'Print receipt',
                    onPressed: printState.isLoading ? null : () => _printReceipt(context, ref, sale),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: detail.when(
        data: (sale) {
          if (sale == null) {
            return const Center(
              child: Text('Sale not found', key: Key('sale_detail_not_found')),
            );
          }
          return ListView(
            key: const Key('sale_detail_content'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                sale.provisionalInvoiceNumber,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(_formatTimestamp(sale.completedAt)),
              const SizedBox(height: 16),
              ...sale.lines.map(
                (line) => ListTile(
                  key: Key('sale_detail_line_${line.productId}'),
                  title: Text(line.productName ?? line.productId),
                  subtitle: Text(
                    'x${line.quantity} @ ${Money(line.unitPriceMinorUnits).format()}',
                  ),
                  trailing: Text(Money(line.lineTotalMinorUnits).format()),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    Money(sale.grandTotalMinorUnits).format(),
                    key: const Key('sale_detail_total'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Could not load sale: $error')),
      ),
    );
  }
}
