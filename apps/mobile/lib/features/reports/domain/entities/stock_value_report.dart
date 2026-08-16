/// One product's contribution to the stock value report (FR-072) — value is
/// `balance × price_minor_units`, against selling price (the only monetary
/// field a product carries in this schema — no separate cost field exists,
/// docs/modules/reports/specification.md §2).
class StockValueEntry {
  const StockValueEntry({
    required this.productId,
    required this.productName,
    required this.balance,
    required this.valueMinorUnits,
  });

  final String productId;
  final String productName;
  final double balance;
  final int valueMinorUnits;
}

class StockValueReport {
  const StockValueReport({required this.totalMinorUnits, required this.entries});

  final int totalMinorUnits;
  final List<StockValueEntry> entries;
}
