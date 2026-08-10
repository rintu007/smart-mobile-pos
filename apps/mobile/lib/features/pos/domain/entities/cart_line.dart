/// One product's quantity in the in-progress cart. Not synced or persisted
/// on its own — a cart only becomes durable when `completeSale` writes it as
/// a `sales`/`sale_line_items` pair; per pos/specification.md §2, M0 has no
/// hold/resume, so an abandoned cart simply disappears with the screen.
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
