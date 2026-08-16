/// Plain Dart, per mobile-structure.md §2 — no Drift, no Flutter.
class Customer {
  const Customer({required this.id, this.name, this.phone});

  final String id;

  /// `name`/`phone` both nullable — customers.md's own "at least one of the
  /// two, never both null" rule is enforced at creation, not shape-level.
  final String? name;
  final String? phone;
}
