/// One line item within a [SaleDetail]. `productName` is `null` when the
/// referenced product is no longer in the local cache — not reachable yet
/// (nothing deletes products), but handled rather than assumed, per
/// sales-invoices/specification.md §2.
///
/// `id` added Sprint 34 (backlog.md M3 item 4) — Returns' own
/// `POST /returns` needs each line's own id as `original_sale_line_item_id`
/// (docs/modules/returns/specification.md §1b). For a locally-sourced
/// [SaleDetail] (this device's own `getSaleDetail`), it's the local
/// `sale_line_items.id` the row already had; for a network-sourced one
/// (`lookupSale`/`fetchRemoteSaleDetail`), it's the server's own
/// `sale_line_items.id`, now exposed by `formatSale`'s own Sprint 34
/// correction.
class SaleLineDetail {
  const SaleLineDetail({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceMinorUnits,
    required this.lineTotalMinorUnits,
  });

  final String id;
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
