import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/catalogue/domain/entities/category.dart';
import 'package:mobile/features/catalogue/domain/entities/product.dart';
import 'package:mobile/features/catalogue/domain/entities/unit.dart';
import 'package:mobile/features/catalogue/domain/repositories/product_repository.dart';
import 'package:mobile/features/catalogue/presentation/providers/category_providers.dart';
import 'package:mobile/features/catalogue/presentation/providers/product_providers.dart';
import 'package:mobile/features/catalogue/presentation/providers/unit_providers.dart';
import 'package:mobile/features/catalogue/presentation/screens/add_product_screen.dart';

/// A fake, not a mock — same reasoning as the authentication feature's
/// `_FakeAuthRepository`.
class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({this.createBehavior});

  final Future<void> Function()? createBehavior;
  bool createCalled = false;
  String? lastCategoryId;
  String? lastUnitId;

  @override
  Future<Product> createProduct({
    required String id,
    required String name,
    required int priceMinorUnits,
    required String categoryId,
    required String unitId,
  }) async {
    createCalled = true;
    lastCategoryId = categoryId;
    lastUnitId = unitId;
    if (createBehavior != null) await createBehavior!();
    return Product(
      id: id,
      name: name,
      priceMinorUnits: priceMinorUnits,
      categoryId: categoryId,
      unitId: unitId,
    );
  }

  @override
  Future<List<Product>> listAll() async => [];
}

const _categories = [Category(id: 'cat-1', name: 'Dairy')];
const _units = [Unit(id: 'unit-1', name: 'Kilogram', symbol: 'kg', allowsFractional: true)];

Widget _wrap(Widget child, {required ProductRepository repository}) {
  return ProviderScope(
    overrides: [
      productRepositoryProvider.overrideWithValue(repository),
      categoriesListProvider.overrideWith((ref) async => _categories),
      unitsListProvider.overrideWith((ref) async => _units),
    ],
    child: MaterialApp(
      home: child,
      // AddProductScreen calls Navigator.pop() on success — a route below
      // it is needed for that pop to have somewhere to go in a test host.
      navigatorObservers: [],
    ),
  );
}

Future<void> _selectDropdownValue(WidgetTester tester, Key fieldKey, String label) async {
  await tester.tap(find.byKey(fieldKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders name/price/category/unit fields and a submit button', (tester) async {
    await tester.pumpWidget(
      _wrap(const AddProductScreen(), repository: _FakeProductRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_product_name_field')), findsOneWidget);
    expect(find.byKey(const Key('add_product_price_field')), findsOneWidget);
    expect(find.byKey(const Key('add_product_category_field')), findsOneWidget);
    expect(find.byKey(const Key('add_product_unit_field')), findsOneWidget);
    expect(find.byKey(const Key('add_product_submit_button')), findsOneWidget);
  });

  testWidgets('submitting empty fields shows inline validation and calls nothing', (
    tester,
  ) async {
    final repository = _FakeProductRepository();
    await tester.pumpWidget(_wrap(const AddProductScreen(), repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add_product_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a product name.'), findsOneWidget);
    expect(find.text('Enter a valid, non-negative price.'), findsOneWidget);
    expect(find.text('Select a category.'), findsOneWidget);
    expect(find.text('Select a unit.'), findsOneWidget);
    expect(repository.createCalled, isFalse);
  });

  testWidgets('a non-numeric price is rejected by validation', (tester) async {
    final repository = _FakeProductRepository();
    await tester.pumpWidget(_wrap(const AddProductScreen(), repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('add_product_name_field')),
      'Filter coffee',
    );
    await tester.enterText(
      find.byKey(const Key('add_product_price_field')),
      'not-a-number',
    );
    await tester.tap(find.byKey(const Key('add_product_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid, non-negative price.'), findsOneWidget);
    expect(repository.createCalled, isFalse);
  });

  testWidgets('valid submit (including category/unit selection) shows loading, then succeeds', (
    tester,
  ) async {
    final repository = _FakeProductRepository(
      createBehavior: () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpWidget(_wrap(const AddProductScreen(), repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('add_product_name_field')),
      'Filter coffee',
    );
    await tester.enterText(find.byKey(const Key('add_product_price_field')), '15.00');
    await _selectDropdownValue(tester, const Key('add_product_category_field'), 'Dairy');
    await _selectDropdownValue(tester, const Key('add_product_unit_field'), 'Kilogram (kg)');

    await tester.tap(find.byKey(const Key('add_product_submit_button')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(repository.createCalled, isTrue);
    expect(repository.lastCategoryId, 'cat-1');
    expect(repository.lastUnitId, 'unit-1');
    expect(find.byKey(const Key('add_product_error_text')), findsNothing);
  });

  testWidgets('a thrown failure renders inline error text', (tester) async {
    final repository = _FakeProductRepository(
      createBehavior: () async => throw Exception('write failed'),
    );
    await tester.pumpWidget(_wrap(const AddProductScreen(), repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('add_product_name_field')),
      'Filter coffee',
    );
    await tester.enterText(find.byKey(const Key('add_product_price_field')), '15.00');
    await _selectDropdownValue(tester, const Key('add_product_category_field'), 'Dairy');
    await _selectDropdownValue(tester, const Key('add_product_unit_field'), 'Kilogram (kg)');

    await tester.tap(find.byKey(const Key('add_product_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_product_error_text')), findsOneWidget);
  });
}
