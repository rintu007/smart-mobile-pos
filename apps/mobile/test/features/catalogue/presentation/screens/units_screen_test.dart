import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/catalogue/domain/entities/unit.dart';
import 'package:mobile/features/catalogue/domain/repositories/unit_repository.dart';
import 'package:mobile/features/catalogue/presentation/providers/unit_providers.dart';
import 'package:mobile/features/catalogue/presentation/screens/units_screen.dart';

/// A fake, not a mock — same reasoning as `_FakeCategoryRepository`.
class _FakeUnitRepository implements UnitRepository {
  final List<Unit> _units = [];
  bool createCalled = false;
  bool? lastAllowsFractional;

  @override
  Future<Unit> createUnit({
    required String id,
    required String name,
    required String symbol,
    required bool allowsFractional,
  }) async {
    createCalled = true;
    lastAllowsFractional = allowsFractional;
    final unit = Unit(id: id, name: name, symbol: symbol, allowsFractional: allowsFractional);
    _units.add(unit);
    return unit;
  }

  @override
  Future<List<Unit>> listAll() async => List.of(_units);

  @override
  Future<void> refreshFromServer() async {}
}

Widget _wrap(UnitRepository repository) {
  return ProviderScope(
    overrides: [unitRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: UnitsScreen()),
  );
}

void main() {
  testWidgets('shows the empty state when there are no units yet', (tester) async {
    await tester.pumpWidget(_wrap(_FakeUnitRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('units_empty')), findsOneWidget);
  });

  testWidgets('creating a unit via the dialog adds it to the list', (tester) async {
    final repository = _FakeUnitRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_unit_fab')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('unit_name_field')), 'Kilogram');
    await tester.enterText(find.byKey(const Key('unit_symbol_field')), 'kg');
    await tester.tap(find.byKey(const Key('unit_allows_fractional_checkbox')));
    await tester.tap(find.byKey(const Key('unit_dialog_save_button')));
    await tester.pumpAndSettle();

    expect(repository.createCalled, isTrue);
    expect(repository.lastAllowsFractional, isTrue);
    expect(find.byKey(const Key('units_list')), findsOneWidget);
    expect(find.text('Kilogram'), findsOneWidget);
  });

  testWidgets('the dialog rejects an empty name or symbol', (tester) async {
    final repository = _FakeUnitRepository();
    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_unit_fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit_dialog_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a unit name.'), findsOneWidget);
    expect(find.text('Enter a symbol.'), findsOneWidget);
    expect(repository.createCalled, isFalse);
  });
}
