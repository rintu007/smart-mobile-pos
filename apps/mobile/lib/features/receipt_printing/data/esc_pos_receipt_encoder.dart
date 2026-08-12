import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../domain/entities/receipt_document.dart';

/// Turns a [ReceiptDocument] into ESC/POS command bytes for a 58 mm printer
/// — backlog.md item 10 scopes 58 mm only, not 80 mm (receipt-design.md §2's
/// second width column is out of scope this sprint). `CapabilityProfile.load()`
/// reads `esc_pos_utils_plus`'s bundled `capabilities.json` via `rootBundle`,
/// so this needs a Flutter binding initialised — true at runtime by
/// construction, and in tests via `TestWidgetsFlutterBinding.ensureInitialized()`
/// (see `esc_pos_receipt_encoder_test.dart`).
class EscPosReceiptEncoder {
  const EscPosReceiptEncoder();

  Future<List<int>> encode(ReceiptDocument doc) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    final bytes = <int>[];

    bytes.addAll(
      generator.text(
        doc.shopName,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('Invoice #${doc.invoiceNumber}'));
    bytes.addAll(
      generator.text(doc.dateLabel, styles: const PosStyles(align: PosAlign.right)),
    );
    bytes.addAll(generator.hr());

    for (final line in doc.lineItems) {
      bytes.addAll(generator.text(line.name));
      bytes.addAll(
        generator.row([
          PosColumn(text: '  ${line.quantity} x ${line.unitPriceLabel}', width: 7),
          PosColumn(
            text: line.lineTotalLabel,
            width: 5,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }

    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.row([
        PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: doc.totalLabel,
          width: 6,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]),
    );
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(doc.paymentLabel));
    bytes.addAll(generator.hr());
    bytes.addAll(
      generator.text(doc.footerMessage, styles: const PosStyles(align: PosAlign.center)),
    );
    bytes.addAll(generator.cut());

    return bytes;
  }
}
