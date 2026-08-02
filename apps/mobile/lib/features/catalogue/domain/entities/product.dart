/// Plain Dart, per mobile-structure.md §2 — no Drift, no Flutter.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.priceMinorUnits,
  });

  final String id;
  final String name;

  /// Minor currency units, never a decimal — per ADR-0006.
  final int priceMinorUnits;
}
