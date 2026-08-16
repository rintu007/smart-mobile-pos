/// One product's quantity in the in-progress cart. Never synced directly —
/// only a `completed` sale's line items ever cross the wire (sales.md's own
/// note). Since Sprint 30 (Hold/Resume), the cart itself *is* continuously
/// persisted locally as a `draft`/`held` `sales`/`sale_line_items` pair, kept
/// in sync with `CartController`'s state on every mutation
/// (pos/specification.md §1/§2, navigation-model.md §4) — it no longer
/// simply disappears with the screen.
class CartLine {
  const CartLine({
    required this.productId,
    required this.productName,
    required this.unitPriceMinorUnits,
    required this.quantity,
  });

  final String productId;
  final String productName;
  final int unitPriceMinorUnits;

  /// Whole numbers only — pos/specification.md §2's M0 simplification
  /// (Units doesn't exist yet, so nothing establishes whether a product
  /// allows fractional quantities).
  final int quantity;

  int get lineTotalMinorUnits => unitPriceMinorUnits * quantity;

  CartLine copyWith({int? quantity}) => CartLine(
    productId: productId,
    productName: productName,
    unitPriceMinorUnits: unitPriceMinorUnits,
    quantity: quantity ?? this.quantity,
  );
}
