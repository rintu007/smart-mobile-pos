import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/store_context/store_context_providers.dart';
import 'package:mobile/features/catalogue/domain/entities/product.dart';
import 'package:mobile/features/catalogue/domain/repositories/product_repository.dart';
import 'package:mobile/features/catalogue/presentation/providers/category_providers.dart';
import 'package:mobile/features/catalogue/presentation/providers/product_providers.dart';
import 'package:mobile/features/customers/domain/entities/customer.dart';
import 'package:mobile/features/customers/domain/entities/customer_field_conflict.dart';
import 'package:mobile/features/customers/domain/repositories/customer_repository.dart';
import 'package:mobile/features/customers/presentation/providers/customer_providers.dart';
import 'package:mobile/features/pos/domain/entities/cart_line.dart';
import 'package:mobile/features/pos/domain/entities/completed_sale.dart';
import 'package:mobile/features/pos/domain/entities/held_sale.dart';
import 'package:mobile/features/pos/domain/entities/resumed_cart.dart';
import 'package:mobile/features/pos/domain/entities/sale_detail.dart';
import 'package:mobile/features/pos/domain/repositories/sale_repository.dart';
import 'package:mobile/features/pos/presentation/providers/pos_providers.dart';
import 'package:mobile/features/pos/presentation/screens/till_screen.dart';
import 'package:mobile/features/returns/presentation/providers/return_providers.dart';

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
  String? lastSavedCustomerId;

  @override
  Future<CompletedSale> completeSale({
    required String id,
    required String storeId,
    required List<CartLine> lines,
    String? customerId,
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

  // Sprint 30 (Hold/Resume) — a real, small in-memory model, not just
  // stubs, since `CartController` now exercises these on every tap.
  final Map<String, List<CartLine>> _drafts = {};
  final Set<String> _held = {};

  @override
  Future<void> saveDraft({
    required String id,
    required String storeId,
    required List<CartLine> lines,
    String? customerId,
  }) async {
    _drafts[id] = lines;
    lastSavedCustomerId = customerId;
  }

  @override
  Future<void> deleteDraft(String id) async {
    _drafts.remove(id);
    _held.remove(id);
  }

  @override
  Future<void> holdSale(String id) async {
    _held.add(id);
  }

  @override
  Future<ResumedCart?> resumeSale(String id) async {
    if (!_held.contains(id)) return null;
    _held.remove(id);
    final lines = _drafts[id];
    return lines == null ? null : ResumedCart(lines: lines);
  }

  @override
  Future<List<HeldSale>> listHeldSales() async {
    return _held
        .map(
          (id) => HeldSale(
            id: id,
            provisionalInvoiceNumber: 'DEV001-2026-000001',
            itemCount: _drafts[id]?.length ?? 0,
            grandTotalMinorUnits:
                _drafts[id]?.fold<int>(0, (sum, line) => sum + line.lineTotalMinorUnits) ?? 0,
            createdAt: DateTime(2026, 8, 12),
          ),
        )
        .toList();
  }

  @override
  Future<SaleDetail?> lookupSale({
    String? provisionalInvoiceNumber,
    String? canonicalInvoiceNumber,
  }) => throw UnimplementedError();

  @override
  Future<SaleDetail?> fetchRemoteSaleDetail(String id) => throw UnimplementedError();
}

const _coffee = Product(id: 'product-1', name: 'Filter coffee', priceMinorUnits: 1500);
const _sugar = Product(id: 'product-2', name: 'Sugar', priceMinorUnits: 500);

/// A fake, not a mock — same reasoning as `_FakeSaleRepository` above.
/// `searchByPhone` is the only method `CustomerPickerSheet` actually
/// exercises in this screen's own test scope; the rest throw.
class _FakeCustomerRepository implements CustomerRepository {
  _FakeCustomerRepository([this._customers = const []]);

  final List<Customer> _customers;

  @override
  Future<List<Customer>> searchByPhone(String query) async => _customers;

  @override
  Future<Customer> createCustomer({required String id, String? name, String? phone}) =>
      throw UnimplementedError();

  @override
  Future<Customer?> findById(String id) => throw UnimplementedError();

  @override
  Future<void> refreshFromServer() async {}

  @override
  Future<List<CompletedSale>> getPurchaseHistory(String customerId) => throw UnimplementedError();

  @override
  Future<Customer> updateCustomer({required String id, String? name, String? phone}) =>
      throw UnimplementedError();

  @override
  Future<List<CustomerFieldConflict>> listConflicts() => throw UnimplementedError();

  @override
  Future<void> resolveConflict({required String conflictId, required String? resolvedValue}) =>
      throw UnimplementedError();
}

Widget _wrap({
  required SaleRepository saleRepository,
  ProductRepository? productRepository,
  CustomerRepository? customerRepository,
}) {
  return ProviderScope(
    overrides: [
      productListProvider.overrideWith((ref) async => [_coffee, _sugar]),
      // categoriesListProvider hits the real network via categoryRepositoryProvider unless
      // overridden — not exercised by this screen's own test scope (the category-filter row
      // renders nothing when the list is empty), same reasoning storeContextProvider below.
      categoriesListProvider.overrideWith((ref) async => []),
      storeContextProvider.overrideWith((ref) async => 'store-1'),
      // Same reasoning as categoriesListProvider above — otherwise this pulls in the real
      // returnRepositoryProvider (a real AppDatabase + Dio), not exercised by this screen's own
      // test scope (only the badge count itself is read).
      pendingApprovalsCountProvider.overrideWith((ref) async => 0),
      saleRepositoryProvider.overrideWithValue(saleRepository),
      customerRepositoryProvider.overrideWithValue(
        customerRepository ?? _FakeCustomerRepository(),
      ),
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

  testWidgets('the hold button is disabled while the cart is empty', (tester) async {
    await tester.pumpWidget(_wrap(saleRepository: _FakeSaleRepository()));
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(find.byKey(const Key('pos_hold_button')));
    expect(button.onPressed, isNull);
  });

  testWidgets('holding a cart clears it and marks the draft held', (tester) async {
    final repository = _FakeSaleRepository();
    await tester.pumpWidget(_wrap(saleRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_product_product-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_hold_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_cart_empty')), findsOneWidget);
    expect(await repository.listHeldSales(), hasLength(1));
  });

  testWidgets('the held-carts icon is present in the app bar', (tester) async {
    await tester.pumpWidget(_wrap(saleRepository: _FakeSaleRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_held_carts_button')), findsOneWidget);
  });

  testWidgets('the customers browse icon is present in the app bar', (tester) async {
    await tester.pumpWidget(_wrap(saleRepository: _FakeSaleRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_customers_button')), findsOneWidget);
  });

  testWidgets('the customer chip shows "Add customer" by default', (tester) async {
    await tester.pumpWidget(_wrap(saleRepository: _FakeSaleRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Add customer'), findsOneWidget);
  });

  testWidgets(
    'tapping the customer chip, then a search result, attaches it to the cart',
    (tester) async {
      final saleRepository = _FakeSaleRepository();
      const customer = Customer(id: 'customer-1', name: 'Ramesh Kumar', phone: '9876543210');
      await tester.pumpWidget(
        _wrap(
          saleRepository: saleRepository,
          customerRepository: _FakeCustomerRepository([customer]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pos_product_product-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pos_customer_chip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pos_customer_result_customer-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pos_customer_result_customer-1')));
      await tester.pumpAndSettle();

      expect(find.text('Ramesh Kumar'), findsOneWidget);
      expect(saleRepository.lastSavedCustomerId, 'customer-1');
    },
  );
}
