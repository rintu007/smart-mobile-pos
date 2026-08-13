/// Plain Dart, per mobile-structure.md §2 — no Drift, no Flutter.
class Unit {
  const Unit({
    required this.id,
    required this.name,
    required this.symbol,
    required this.allowsFractional,
  });

  final String id;
  final String name;
  final String symbol;
  final bool allowsFractional;
}
