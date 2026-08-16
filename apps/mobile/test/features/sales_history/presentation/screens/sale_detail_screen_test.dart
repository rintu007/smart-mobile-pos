import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/pos/domain/entities/cart_line.dart';
import 'package:mobile/features/pos/domain/entities/completed_sale.dart';
import 'package:mobile/features/pos/domain/entities/held_sale.dart';
import 'package:mobile/features/pos/domain/entities/resumed_cart.dart';
import 'package:mobile/features/pos/domain/entities/sale_detail.dart';
import 'package:mobile/features/pos/domain/repositories/sale_repository.dart';
import 'package:mobile/features/pos/presentation/providers/pos_providers.dart';
import 'package:mobile/features/sales_history/presentation/screens/sale_detail_screen.dart';

class _FakeSaleRepository implements SaleRepository {
  _FakeSaleRepository(this.detail);

  final SaleDetail? detail;

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
  Future<SaleDetail?> getSaleDetail(String id) async => detail;

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

  @override
  Future<SaleDetail?> lookupSale({
    String? provisionalInvoiceNumber,
    String? canonicalInvoiceNumber,
  }) => throw UnimplementedError();

  @override
  Future<SaleDetail?> fetchRemoteSaleDetail(String id) => throw UnimplementedError();
}

Widget _wrap(SaleDetail? detail, {String saleId = 'sale-1'}) {
  return ProviderScope(
    overrides: [
      saleRepositoryProvider.overrideWithValue(_FakeSaleRepository(detail)),
    ],
    child: MaterialApp(home: SaleDetailScreen(saleId: saleId)),
  );
}

void main() {
  testWidgets('renders "Sale not found" when the id does not resolve', (tester) async {
    await tester.pumpWidget(_wrap(null));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sale_detail_not_found')), findsOneWidget);
  });

  testWidgets('renders line items and the grand total', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SaleDetail(
          id: 'sale-1',
          provisionalInvoiceNumber: 'DEV001-2026-000001',
          completedAt: DateTime(2026, 8, 12, 14, 30),
          grandTotalMinorUnits: 3500,
          lines: const [
            SaleLineDetail(
              id: 'line-item-1',
              productId: 'product-1',
              productName: 'Filter coffee',
              quantity: 2,
              unitPriceMinorUnits: 1500,
              lineTotalMinorUnits: 3000,
            ),
            SaleLineDetail(
              id: 'line-item-2',
              productId: 'product-2',
              productName: null,
              quantity: 1,
              unitPriceMinorUnits: 500,
              lineTotalMinorUnits: 500,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DEV001-2026-000001'), findsOneWidget);
    expect(find.byKey(const Key('sale_detail_line_product-1')), findsOneWidget);
    expect(find.text('Filter coffee'), findsOneWidget);
    // product-2 has no cached name, falls back to its id.
    expect(find.text('product-2'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('sale_detail_total'))).data,
      '\u{20B9}35.00',
    );
  });
}
