/// Plain Dart, per mobile-structure.md §2 — no Drift, no Flutter.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.priceMinorUnits,
    this.categoryId,
    this.unitId,
  });

  final String id;
  final String name;

  /// Minor currency units, never a decimal — per ADR-0006.
  final int priceMinorUnits;

  /// Nullable here (Sprint 20) even though `/catalogue/add`'s own form now
  /// requires picking both for any *new* product — a row created before this
  /// sprint, or one pulled from the server without them, is still a valid
  /// `Product`.
  final String? categoryId;
  final String? unitId;
}
