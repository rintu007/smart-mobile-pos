/// One product's ranking in the top-products report (FR-073) — over a
/// caller-selected date range, ranked by quantity or value per
/// [ReportsRepository.topProducts]'s own `sortBy` argument.
class TopProductEntry {
  const TopProductEntry({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.valueMinorUnits,
  });

  final String productId;
  final String productName;
  final double quantity;
  final int valueMinorUnits;
}
