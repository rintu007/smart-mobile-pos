import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/catalogue/domain/entities/product.dart';
import 'package:mobile/features/catalogue/domain/repositories/product_repository.dart';
import 'package:mobile/features/catalogue/presentation/providers/product_providers.dart';
import 'package:mobile/features/catalogue/presentation/screens/add_product_screen.dart';

/// A fake, not a mock — same reasoning as the authentication feature's
/// `_FakeAuthRepository`.
class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({this.createBehavior});

  final Future<void> Function()? createBehavior;
  bool createCalled = false;

  @override
  Future<Product> createProduct({
    required String id,
    required String name,
    required int priceMinorUnits,
  }) async {
    createCalled = true;
    if (createBehavior != null) await createBehavior!();
    return Product(id: id, name: name, priceMinorUnits: priceMinorUnits);
  }

  @override
  Future<List<Product>> listAll() async => [];
}

Widget _wrap(Widget child, {required ProductRepository repository}) {
  return ProviderScope(
    overrides: [productRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      home: child,
      // AddProductScreen calls Navigator.pop() on success — a route below
      // it is needed for that pop to have somewhere to go in a test host.
      navigatorObservers: [],
    ),
  );
}

void main() {
  testWidgets('renders name/price fields and a submit button', (tester) async {
    await tester.pumpWidget(
      _wrap(const AddProductScreen(), repository: _FakeProductRepository()),
    );

    expect(find.byKey(const Key('add_product_name_field')), findsOneWidget);
    expect(find.byKey(const Key('add_product_price_field')), findsOneWidget);
    expect(find.byKey(const Key('add_product_submit_button')), findsOneWidget);
  });

  testWidgets('submitting empty fields shows inline validation and calls nothing', (
    tester,
  ) async {
    final repository = _FakeProductRepository();
    await tester.pumpWidget(_wrap(const AddProductScreen(), repository: repository));

    await tester.tap(find.byKey(const Key('add_product_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a product name.'), findsOneWidget);
    expect(find.text('Enter a valid, non-negative price.'), findsOneWidget);
    expect(repository.createCalled, isFalse);
  });

  testWidgets('a non-numeric price is rejected by validation', (tester) async {
    final repository = _FakeProductRepository();
    await tester.pumpWidget(_wrap(const AddProductScreen(), repository: repository));

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

  testWidgets('valid submit shows the loading state, then succeeds with no error', (
    tester,
  ) async {
    final repository = _FakeProductRepository(
      createBehavior: () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpWidget(_wrap(const AddProductScreen(), repository: repository));

    await tester.enterText(
      find.byKey(const Key('add_product_name_field')),
      'Filter coffee',
    );
    await tester.enterText(find.byKey(const Key('add_product_price_field')), '15.00');
    await tester.tap(find.byKey(const Key('add_product_submit_button')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repository.createCalled, isTrue);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add_product_error_text')), findsNothing);
  });

  testWidgets('a thrown failure renders inline error text', (tester) async {
    final repository = _FakeProductRepository(
      createBehavior: () async => throw Exception('write failed'),
    );
    await tester.pumpWidget(_wrap(const AddProductScreen(), repository: repository));

    await tester.enterText(
      find.byKey(const Key('add_product_name_field')),
      'Filter coffee',
    );
    await tester.enterText(find.byKey(const Key('add_product_price_field')), '15.00');
    await tester.tap(find.byKey(const Key('add_product_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_product_error_text')), findsOneWidget);
  });
}
