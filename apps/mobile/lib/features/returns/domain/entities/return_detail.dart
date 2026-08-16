/// One line item within a [ReturnDetail]. Refund amounts are always
/// server-computed (DR-014) — never sent from mobile, only ever received.
class ReturnLineItem {
  const ReturnLineItem({
    required this.originalSaleLineItemId,
    required this.quantity,
    required this.refundAmountMinorUnits,
  });

  final String originalSaleLineItemId;
  final int quantity;
  final int refundAmountMinorUnits;
}

/// A single return's full detail, with line items — `GET /returns/{id}`,
/// and the response of create/approve/reject. Distinct from [ReturnSummary]
/// (list rows, no line items), the same split `pos`'s own
/// `CompletedSale`/`SaleDetail` already established.
class ReturnDetail {
  const ReturnDetail({
    required this.id,
    required this.originalSaleId,
    required this.status,
    required this.refundTotalMinorUnits,
    this.approvedBy,
    this.completedAt,
    required this.createdAt,
    required this.lineItems,
  });

  final String id;
  final String originalSaleId;

  /// 'pending_approval' / 'completed' / 'rejected'.
  final String status;
  final int refundTotalMinorUnits;
  final String? approvedBy;
  final DateTime? completedAt;
  final DateTime createdAt;
  final List<ReturnLineItem> lineItems;
}
