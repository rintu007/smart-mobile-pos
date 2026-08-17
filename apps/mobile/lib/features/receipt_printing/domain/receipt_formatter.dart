import '../../pos/domain/entities/sale_detail.dart';
import 'entities/receipt_document.dart';

const _monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Builds a [ReceiptDocument] from a completed sale —
/// [receipt-design.md §2](../../../../../../docs/10-design-system/receipt-design.md#2-layout--common-structure-two-widths)'s
/// zones, deliberately narrowed to what M0's local data actually has:
/// **omitted** — shop address/GSTIN (Company & Store Setup never collects/
/// caches either locally), cashier name (no local display-name cache
/// exists yet), discount/tax breakdown (M1/M2 scope, per
/// pos/specification.md §1), split payment (M0 is cash-only). The header is
/// shop name only; the payment line is always `Paid (Cash)`. Each omission
/// mirrors a gap this project has already named elsewhere (products/pos
/// specs' own M0-minimal cuts) — not a new one invented here.
///
/// Amounts render **without** the ₹ symbol, unlike [Money.format()] — most
/// thermal printers' default ESC/POS code pages (CP437 etc.) can't render
/// the Rupee glyph reliably, and receipt-design.md §3's own worked example
/// shows plain numbers for exactly this reason.
class ReceiptFormatter {
  const ReceiptFormatter();

  ReceiptDocument build({
    required SaleDetail sale,
    required String shopName,
    String footerMessage = 'Thank you, visit again!',
  }) {
    return ReceiptDocument(
      shopName: shopName,
      invoiceNumber: sale.provisionalInvoiceNumber,
      dateLabel: _formatDate(sale.completedAt),
      lineItems: sale.lines
          .map(
            (line) => ReceiptLineItem(
              name: line.productName ?? line.productId,
              quantity: line.quantity,
              unitPriceLabel: _plainAmount(line.unitPriceMinorUnits),
              lineTotalLabel: _plainAmount(line.lineTotalMinorUnits),
            ),
          )
          .toList(),
      totalLabel: _plainAmount(sale.grandTotalMinorUnits),
      paymentLabel: 'Paid (Cash)  ${_plainAmount(sale.grandTotalMinorUnits)}',
      footerMessage: footerMessage,
    );
  }

  /// `/settings/printer`'s "Test print" button (Sprint 39, backlog.md M4
  /// item 4) — FR-077's "test-printed from settings, independent of any
  /// sale," so this deliberately does not depend on a real [SaleDetail] at
  /// all, unlike [build] above.
  ReceiptDocument buildTest({required String shopName, String footerMessage = 'Thank you, visit again!'}) {
    return ReceiptDocument(
      shopName: shopName,
      invoiceNumber: 'TEST',
      dateLabel: _formatDate(DateTime.now()),
      lineItems: const [
        ReceiptLineItem(name: 'Test item', quantity: 1, unitPriceLabel: '0.00', lineTotalLabel: '0.00'),
      ],
      totalLabel: '0.00',
      paymentLabel: 'Test print — no payment taken',
      footerMessage: footerMessage,
    );
  }

  String _plainAmount(int minorUnits) {
    final rupees = minorUnits ~/ 100;
    final paise = (minorUnits % 100).abs().toString().padLeft(2, '0');
    return '$rupees.$paise';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}-'
        '${_monthAbbreviations[local.month - 1]}-${local.year}';
  }
}
