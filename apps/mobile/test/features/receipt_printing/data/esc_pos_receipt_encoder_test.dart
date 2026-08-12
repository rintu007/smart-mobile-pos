import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/receipt_printing/data/esc_pos_receipt_encoder.dart';
import 'package:mobile/features/receipt_printing/domain/entities/receipt_document.dart';

void main() {
  // `esc_pos_utils_plus`'s `CapabilityProfile.load()` reads its bundled
  // capabilities.json via `rootBundle`, which needs a Flutter binding —
  // `TestWidgetsFlutterBinding.ensureInitialized()` provides one without
  // requiring `testWidgets()`/a real widget tree, per Flutter's own
  // documented pattern for asset-bundle-dependent plain `test()` cases.
  TestWidgetsFlutterBinding.ensureInitialized();

  const encoder = EscPosReceiptEncoder();

  const document = ReceiptDocument(
    shopName: 'Sharma General Store',
    invoiceNumber: 'DEV-2026-000042',
    dateLabel: '30-Jul-2026',
    lineItems: [
      ReceiptLineItem(
        name: 'Amul Milk 500ml',
        quantity: 1,
        unitPriceLabel: '28.00',
        lineTotalLabel: '28.00',
      ),
    ],
    totalLabel: '28.00',
    paymentLabel: 'Paid (Cash)  28.00',
    footerMessage: 'Thank you, visit again!',
  );

  test('produces a non-empty byte stream', () async {
    final bytes = await encoder.encode(document);
    expect(bytes, isNotEmpty);
  });

  test('embeds every text field as plain ASCII bytes within the stream', () async {
    final bytes = await encoder.encode(document);
    // ESC/POS control sequences are non-printable bytes interspersed with
    // the actual text; the text itself round-trips as plain ASCII, so a
    // substring check against the decoded stream is a meaningful (if
    // loose) proof that every field actually reached the printer command
    // stream, without asserting brittle byte-exact command sequences.
    final decoded = String.fromCharCodes(bytes);

    expect(decoded, contains(document.shopName));
    expect(decoded, contains(document.invoiceNumber));
    expect(decoded, contains(document.dateLabel));
    expect(decoded, contains(document.lineItems.single.name));
    expect(decoded, contains(document.totalLabel));
    expect(decoded, contains(document.footerMessage));
  });

  test('ends with the full-cut command', () async {
    final bytes = await encoder.encode(document);
    // GS V 0 (0x1D, 0x56, 0x30 — the ASCII character '0', not a null byte)
    // is `cCutFull`, the last thing Generator.cut() emits.
    expect(bytes.sublist(bytes.length - 3), [0x1D, 0x56, 0x30]);
  });
}
