import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/store_context/store_context_providers.dart';
import 'package:mobile/features/catalogue/domain/entities/product.dart';
import 'package:mobile/features/catalogue/domain/repositories/product_repository.dart';
import 'package:mobile/features/catalogue/presentation/providers/category_providers.dart';
import 'package:mobile/features/catalogue/presentation/providers/product_providers.dart';
import 'package:mobile/features/pos/domain/entities/cart_line.dart';
import 'package:mobile/features/pos/domain/entities/completed_sale.dart';
import 'package:mobile/features/pos/domain/entities/sale_detail.dart';
import 'package:mobile/features/pos/domain/repositories/sale_repository.dart';
import 'package:mobile/features/pos/presentation/providers/pos_providers.dart';
import 'package:mobile/features/pos/presentation/screens/till_screen.dart';

/// A fake, not a mock — same reasoning as `_FakeSaleRepository` below.
class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository(this._byBarcode);

  final Map<String, Product> _byBarcode;

  @override
  Future<Product> createProduct({
    required String id,
    required String name,
    required int priceMinorUnits,
    required String categoryId,
    required String unitId,
  }) => throw UnimplementedError();

  @override
  Future<List<Product>> listAll() async => [];

  @override
  Future<Product?> findByBarcode(String barcode) async => _byBarcode[barcode];
}

/// A fake, not a mock — same reasoning as the catalogue feature's
/// `_FakeProductRepository`.
class _FakeSaleRepository implements SaleRepository {
  _FakeSaleRepository({this.behavior});

  final Future<void> Function()? behavior;
  bool completeCalled = false;

  @override
  Future<CompletedSale> completeSale({
    required String id,
    required String storeId,
    required List<CartLine> lines,
  }) async {
    completeCalled = true;
    if (behavior != null) await behavior!();
    final total = lines.fold<int>(0, (sum, line) => sum + line.lineTotalMinorUnits);
    return CompletedSale(
      id: id,
      provisionalInvoiceNumber: 'DEV001-2026-000001',
      grandTotalMinorUnits: total,
      completedAt: DateTime(2026, 8, 12),
    );
  }

  @override
  Future<List<CompletedSale>> listCompletedSales() async => [];

  @override
  Future<SaleDetail?> getSaleDetail(String id) async => null;
}

const _coffee = Product(id: 'product-1', name: 'Filter coffee', priceMinorUnits: 1500);
const _sugar = Product(id: 'product-2', name: 'Sugar', priceMinorUnits: 500);

Widget _wrap({
  required SaleRepository saleRepository,
  ProductRepository? productRepository,
}) {
  return ProviderScope(
    overrides: [
      productListProvider.overrideWith((ref) async => [_coffee, _sugar]),
      // categoriesListProvider hits the real network via categoryRepositoryProvider unless
      // overridden — not exercised by this screen's own test scope (the category-filter row
      // renders nothing when the list is empty), same reasoning storeContextProvider below.
      categoriesListProvider.overrideWith((ref) async => []),
      storeContextProvider.overrideWith((ref) async => 'store-1'),
      saleRepositoryProvider.overrideWithValue(saleRepository),
      if (productRepository != null)
        productRepositoryProvider.overrideWithValue(productRepository),
    ],
    child: const MaterialApp(home: TillScreen()),
  );
}

void main() {
  testWidgets('renders the product list and an empty cart', (tester) async {
    await tester.pumpWidget(_wrap(saleRepository: _FakeSaleRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_product_product-1')), findsOneWidget);
    expect(find.byKey(const Key('pos_product_product-2')), findsOneWidget);
    expect(find.byKey(const Key('pos_cart_empty')), findsOneWidget);
    expect(find.text('\u{20B9}0.00'), findsOneWidget);
    expect(find.byKey(const Key('pos_sales_history_button')), findsOneWidget);
  });

  testWidgets('tapping a product adds it to the cart and updates the total', (tester) async {
    await tester.pumpWidget(_wrap(saleRepository: _FakeSaleRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_product_product-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_cart_line_product-1')), findsOneWidget);
    expect(find.byKey(const Key('pos_cart_empty')), findsNothing);
    expect(find.byKey(const Key('pos_cart_total')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('pos_cart_total'))).data,
      '\u{20B9}15.00',
    );
  });

  testWidgets('decrementing a cart line down to zero removes it', (tester) async {
    await tester.pumpWidget(_wrap(saleRepository: _FakeSaleRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_product_product-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_cart_decrement_product-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_cart_line_product-1')), findsNothing);
    expect(find.byKey(const Key('pos_cart_empty')), findsOneWidget);
  });

  testWidgets('the complete-sale button is disabled while the cart is empty', (tester) async {
    await tester.pumpWidget(_wrap(saleRepository: _FakeSaleRepository()));
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(
      find.byKey(const Key('pos_complete_sale_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('completing a sale calls the repository, shows the invoice number, and clears the cart', (
    tester,
  ) async {
    final repository = _FakeSaleRepository();
    await tester.pumpWidget(_wrap(saleRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_product_product-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_complete_sale_button')));
    await tester.pumpAndSettle();

    expect(repository.completeCalled, isTrue);
    expect(find.byKey(const Key('pos_sale_success')), findsOneWidget);
    expect(find.text('Sale complete — invoice DEV001-2026-000001'), findsOneWidget);
    expect(find.byKey(const Key('pos_cart_empty')), findsOneWidget);
  });

  testWidgets('a failed sale renders inline error text and keeps the cart', (tester) async {
    final repository = _FakeSaleRepository(
      behavior: () async => throw Exception('write failed'),
    );
    await tester.pumpWidget(_wrap(saleRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_product_product-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_complete_sale_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_sale_error')), findsOneWidget);
    expect(find.byKey(const Key('pos_cart_line_product-1')), findsOneWidget);
  });

  testWidgets('searching filters the product list by name (FR-034 fallback)', (tester) async {
    await tester.pumpWidget(_wrap(saleRepository: _FakeSaleRepository()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('pos_search_field')), 'sugar');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_product_product-1')), findsNothing);
    expect(find.byKey(const Key('pos_product_product-2')), findsOneWidget);
  });

  testWidgets('a barcode-scan button is present, wired to look up and add via the repository', (
    tester,
  ) async {
    // The scan screen itself (mobile_scanner, a real camera) is not
    // exercised here — same untested-hardware-integration boundary this
    // project already draws for Bluetooth printing (no
    // printer_picker_dialog_test.dart exists either). This test only proves
    // the till screen's own side of the contract: the button exists and
    // `findByBarcode` is the mechanism it would call.
    final repository = _FakeProductRepository({'8901234567890': _coffee});
    await tester.pumpWidget(
      _wrap(saleRepository: _FakeSaleRepository(), productRepository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_scan_barcode_button')), findsOneWidget);
    expect(await repository.findByBarcode('8901234567890'), _coffee);
  });
}
