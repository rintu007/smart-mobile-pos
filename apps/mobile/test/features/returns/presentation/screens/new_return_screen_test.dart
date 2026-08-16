import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/customers/domain/entities/customer.dart';
import 'package:mobile/features/customers/domain/repositories/customer_repository.dart';
import 'package:mobile/features/customers/presentation/providers/customer_providers.dart';
import 'package:mobile/features/pos/domain/entities/cart_line.dart';
import 'package:mobile/features/pos/domain/entities/completed_sale.dart';
import 'package:mobile/features/pos/domain/entities/held_sale.dart';
import 'package:mobile/features/pos/domain/entities/resumed_cart.dart';
import 'package:mobile/features/pos/domain/entities/sale_detail.dart';
import 'package:mobile/features/pos/domain/repositories/sale_repository.dart';
import 'package:mobile/features/pos/presentation/providers/pos_providers.dart';
import 'package:mobile/features/returns/domain/entities/return_detail.dart';
import 'package:mobile/features/returns/domain/entities/return_summary.dart';
import 'package:mobile/features/returns/domain/repositories/return_repository.dart';
import 'package:mobile/features/returns/presentation/providers/return_providers.dart';
import 'package:mobile/features/returns/presentation/screens/new_return_screen.dart';

/// A fake, not a mock — same reasoning `_FakeSaleRepository` established.
class _FakeSaleRepository implements SaleRepository {
  _FakeSaleRepository({this.lookupResult});

  final SaleDetail? lookupResult;

  @override
  Future<SaleDetail?> lookupSale({
    String? provisionalInvoiceNumber,
    String? canonicalInvoiceNumber,
  }) async => lookupResult;

  @override
  Future<SaleDetail?> fetchRemoteSaleDetail(String id) async => lookupResult;

  @override
  Future<CompletedSale> completeSale({
    required String id,
    required String storeId,
    required List<CartLine> lines,
    String? customerId,
  }) => throw UnimplementedError();

  @override
  Future<List<CompletedSale>> listCompletedSales() => throw UnimplementedError();

  @override
  Future<SaleDetail?> getSaleDetail(String id) => throw UnimplementedError();

  @override
  Future<void> saveDraft({
    required String id,
    required String storeId,
    required List<CartLine> lines,
    String? customerId,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteDraft(String id) => throw UnimplementedError();

  @override
  Future<void> holdSale(String id) => throw UnimplementedError();

  @override
  Future<ResumedCart?> resumeSale(String id) => throw UnimplementedError();

  @override
  Future<List<HeldSale>> listHeldSales() => throw UnimplementedError();
}

class _FakeCustomerRepository implements CustomerRepository {
  @override
  Future<List<Customer>> searchByPhone(String query) async => [];

  @override
  Future<Customer> createCustomer({required String id, String? name, String? phone}) =>
      throw UnimplementedError();

  @override
  Future<Customer?> findById(String id) => throw UnimplementedError();

  @override
  Future<void> refreshFromServer() => throw UnimplementedError();

  @override
  Future<List<CompletedSale>> getPurchaseHistory(String customerId) => throw UnimplementedError();
}

class _FakeReturnRepository implements ReturnRepository {
  _FakeReturnRepository(this._result);

  final ReturnDetail _result;
  String? lastOriginalSaleId;
  List<ReturnLineItemInput>? lastLineItems;

  @override
  Future<ReturnDetail> createReturn({
    required String id,
    required String originalSaleId,
    required List<ReturnLineItemInput> lineItems,
  }) async {
    lastOriginalSaleId = originalSaleId;
    lastLineItems = lineItems;
    return _result;
  }

  @override
  Future<ReturnDetail?> getDetail(String id) async => _result;

  @override
  Future<ReturnDetail> approveReturn(String id) async => _result;

  @override
  Future<ReturnDetail> rejectReturn(String id, String reason) => throw UnimplementedError();

  @override
  Future<List<ReturnSummary>> listMine() => throw UnimplementedError();

  @override
  Future<List<ReturnSummary>> listApprovals() => throw UnimplementedError();
}

final _sale = SaleDetail(
  id: 'sale-1',
  provisionalInvoiceNumber: 'DEV-2026-000001',
  completedAt: DateTime(2026, 8, 16),
  grandTotalMinorUnits: 2800,
  lines: const [
    SaleLineDetail(
      id: 'line-1',
      productId: 'product-1',
      productName: 'Amul Milk',
      quantity: 2,
      unitPriceMinorUnits: 1400,
      lineTotalMinorUnits: 2800,
    ),
  ],
);

Widget _wrap({SaleDetail? lookupResult, ReturnRepository? returnRepository}) {
  final router = GoRouter(
    initialLocation: '/returns/new',
    routes: [
      GoRoute(path: '/returns/new', builder: (context, state) => const NewReturnScreen()),
      GoRoute(
        path: '/returns/:id',
        builder: (context, state) => Scaffold(
          body: Text('Return detail ${state.pathParameters['id']}', key: const Key('detail_marker')),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      saleRepositoryProvider.overrideWithValue(_FakeSaleRepository(lookupResult: lookupResult)),
      customerRepositoryProvider.overrideWithValue(_FakeCustomerRepository()),
      if (returnRepository != null) returnRepositoryProvider.overrideWithValue(returnRepository),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('looking up by invoice number shows the located sale\'s line items', (tester) async {
    await tester.pumpWidget(_wrap(lookupResult: _sale));

    await tester.enterText(find.byKey(const Key('returns_lookup_field')), 'DEV-2026-000001');
    await tester.tap(find.byKey(const Key('returns_lookup_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('returns_line_item_line-1')), findsOneWidget);
  });

  testWidgets('shows an error when nothing is found', (tester) async {
    await tester.pumpWidget(_wrap(lookupResult: null));

    await tester.enterText(find.byKey(const Key('returns_lookup_field')), 'nonexistent');
    await tester.tap(find.byKey(const Key('returns_lookup_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('returns_lookup_error')), findsOneWidget);
  });

  testWidgets('confirm is disabled until a line has a positive quantity, then submits', (
    tester,
  ) async {
    final completedResult = ReturnDetail(
      id: 'return-1',
      originalSaleId: 'sale-1',
      status: 'completed',
      refundTotalMinorUnits: 1400,
      completedAt: DateTime(2026, 8, 16),
      createdAt: DateTime(2026, 8, 16),
      lineItems: const [
        ReturnLineItem(originalSaleLineItemId: 'line-1', quantity: 1, refundAmountMinorUnits: 1400),
      ],
    );
    final returnRepository = _FakeReturnRepository(completedResult);
    await tester.pumpWidget(_wrap(lookupResult: _sale, returnRepository: returnRepository));

    await tester.enterText(find.byKey(const Key('returns_lookup_field')), 'DEV-2026-000001');
    await tester.tap(find.byKey(const Key('returns_lookup_button')));
    await tester.pumpAndSettle();

    final confirmButton = tester.widget<FilledButton>(find.byKey(const Key('returns_confirm_button')));
    expect(confirmButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('returns_line_item_increment_line-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('returns_confirm_button')));
    await tester.pumpAndSettle();

    expect(returnRepository.lastOriginalSaleId, 'sale-1');
    expect(returnRepository.lastLineItems, hasLength(1));
    expect(returnRepository.lastLineItems!.single.originalSaleLineItemId, 'line-1');
    expect(returnRepository.lastLineItems!.single.quantity, 1);
    // A completed result navigates straight to the detail screen.
    expect(find.byKey(const Key('detail_marker')), findsOneWidget);
  });

  testWidgets('a pending_approval result shows the inline approve-now prompt', (tester) async {
    final pendingResult = ReturnDetail(
      id: 'return-1',
      originalSaleId: 'sale-1',
      status: 'pending_approval',
      refundTotalMinorUnits: 1400,
      createdAt: DateTime(2026, 8, 16),
      lineItems: const [
        ReturnLineItem(originalSaleLineItemId: 'line-1', quantity: 1, refundAmountMinorUnits: 1400),
      ],
    );
    final returnRepository = _FakeReturnRepository(pendingResult);
    await tester.pumpWidget(_wrap(lookupResult: _sale, returnRepository: returnRepository));

    await tester.enterText(find.byKey(const Key('returns_lookup_field')), 'DEV-2026-000001');
    await tester.tap(find.byKey(const Key('returns_lookup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('returns_line_item_increment_line-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('returns_confirm_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('returns_needs_approval_text')), findsOneWidget);
    expect(find.byKey(const Key('detail_marker')), findsNothing);
  });
}
