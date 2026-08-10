/// Money as integer minor units, per ADR-0006 — never floating point.
/// Previously inlined in `add_product_screen.dart` (the only feature that
/// needed it, per that file's own comment); moved here now that a second
/// feature (`pos`) needs the same conversion — mobile-structure.md §3's rule
/// for when something graduates into `core/`.
class Money {
  const Money(this.minorUnits);

  final int minorUnits;

  /// Decimal major-units string ("12.50") -> `Money`. Returns `null` for
  /// anything that doesn't parse to a non-negative amount, so callers can
  /// use this directly as form-field validation.
  static Money? tryParseMajorUnits(String input) {
    final majorUnits = double.tryParse(input.trim());
    if (majorUnits == null || majorUnits < 0) return null;
    return Money((majorUnits * 100).round());
  }

  /// No currency/locale formatting yet — [OD-01](../../../../docs/01-vision/open-decisions.md)'s
  /// launch market (and therefore currency symbol) is still provisional, so
  /// this hardcodes ₹ rather than pretending a locale decision has been
  /// made. Revisited once OD-01 resolves.
  String format() {
    final rupees = minorUnits ~/ 100;
    final paise = (minorUnits % 100).abs().toString().padLeft(2, '0');
    return '\u{20B9}$rupees.$paise';
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() => format();
}
