/// One line item within a [SaleDetail]. `productName` is `null` when the
/// referenced product is no longer in the local cache — not reachable yet
/// (nothing deletes products), but handled rather than assumed, per
/// sales-invoices/specification.md §2.
class SaleLineDetail {
  const SaleLineDetail({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceMinorUnits,
    required this.lineTotalMinorUnits,
  });

  final String productId;
  final String? productName;
  final int quantity;
  final int unitPriceMinorUnits;
  final int lineTotalMinorUnits;
}

/// A completed sale plus its line items — read-only, assembled for
/// `/sales-history/:id`. Distinct from [CompletedSale] (the immediate result
/// of `completeSale()`), which never includes line items.
class SaleDetail {
  const SaleDetail({
    required this.id,
    required this.provisionalInvoiceNumber,
    required this.completedAt,
    required this.grandTotalMinorUnits,
    required this.lines,
  });

  final String id;
  final String provisionalInvoiceNumber;
  final DateTime completedAt;
  final int grandTotalMinorUnits;
  final List<SaleLineDetail> lines;
}
