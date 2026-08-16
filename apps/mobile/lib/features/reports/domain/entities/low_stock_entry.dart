/// One product below `shop_settings.low_stock_threshold_quantity` (FR-074) —
/// [ReportsRepository.lowStock] returns these sorted furthest-under-threshold
/// first (smallest `balance` first, since `thresholdQuantity` is a single
/// shop-wide value in V1, docs/modules/reports/specification.md §1).
class LowStockEntry {
  const LowStockEntry({
    required this.productId,
    required this.productName,
    required this.balance,
    required this.thresholdQuantity,
  });

  final String productId;
  final String productName;
  final double balance;
  final int thresholdQuantity;
}
