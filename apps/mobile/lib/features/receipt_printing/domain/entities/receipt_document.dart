/// One printable line item — pre-formatted money strings, not [Money]/`int`
/// minor units, so [ReceiptFormatter] is the one place that decides how
/// amounts render on paper (no currency symbol — see that file's own
/// docstring) and every downstream consumer (the ESC/POS encoder, a future
/// PDF renderer per receipt-design.md §4) just lays out text.
class ReceiptLineItem {
  const ReceiptLineItem({
    required this.name,
    required this.quantity,
    required this.unitPriceLabel,
    required this.lineTotalLabel,
  });

  final String name;
  final int quantity;
  final String unitPriceLabel;
  final String lineTotalLabel;
}

/// The full content of one receipt — [receipt-design.md §2](../../../../../../../docs/10-design-system/receipt-design.md)'s
/// zones, narrowed to what M0's local data actually has (see
/// [ReceiptFormatter]'s own docstring for exactly what's omitted and why).
/// Deliberately plain data, no formatting logic — a receipt's *content* is
/// decided once, by [ReceiptFormatter]; how it's rendered (ESC/POS bytes
/// today, a PDF per receipt-design.md §4 later) is a separate, later
/// decision this class doesn't make.
class ReceiptDocument {
  const ReceiptDocument({
    required this.shopName,
    required this.invoiceNumber,
    required this.dateLabel,
    required this.lineItems,
    required this.totalLabel,
    required this.paymentLabel,
    required this.footerMessage,
  });

  final String shopName;
  final String invoiceNumber;
  final String dateLabel;
  final List<ReceiptLineItem> lineItems;
  final String totalLabel;
  final String paymentLabel;
  final String footerMessage;
}
