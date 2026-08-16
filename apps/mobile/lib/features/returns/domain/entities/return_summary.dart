/// A return, without its line items — `GET /returns`/`GET /returns/approvals`
/// list rows, and the local `Returns` cache row. The `CompletedSale` vs.
/// `SaleDetail` list-vs-detail split `pos` already uses for an analogous
/// shape (docs/modules/returns/specification.md §3).
class ReturnSummary {
  const ReturnSummary({
    required this.id,
    required this.originalSaleId,
    required this.status,
    required this.refundTotalMinorUnits,
    this.approvedBy,
    this.completedAt,
    required this.createdAt,
  });

  final String id;
  final String originalSaleId;

  /// 'pending_approval' / 'completed' / 'rejected'.
  final String status;
  final int refundTotalMinorUnits;
  final String? approvedBy;
  final DateTime? completedAt;
  final DateTime createdAt;
}
