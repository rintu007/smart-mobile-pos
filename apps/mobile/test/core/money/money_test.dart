import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/money/money.dart';

void main() {
  test('tryParseMajorUnits converts a decimal string to minor units', () {
    expect(Money.tryParseMajorUnits('12.50')?.minorUnits, 1250);
    expect(Money.tryParseMajorUnits('0')?.minorUnits, 0);
    expect(Money.tryParseMajorUnits('3')?.minorUnits, 300);
  });

  test('tryParseMajorUnits rejects invalid or negative input', () {
    expect(Money.tryParseMajorUnits('not-a-number'), isNull);
    expect(Money.tryParseMajorUnits('-5.00'), isNull);
    expect(Money.tryParseMajorUnits(''), isNull);
  });

  test('format renders rupees and paise', () {
    expect(const Money(1250).format(), '\u{20B9}12.50');
    expect(const Money(0).format(), '\u{20B9}0.00');
    expect(const Money(5).format(), '\u{20B9}0.05');
  });

  test('two Money instances with the same minor units are equal', () {
    expect(const Money(1250), const Money(1250));
  });
}
