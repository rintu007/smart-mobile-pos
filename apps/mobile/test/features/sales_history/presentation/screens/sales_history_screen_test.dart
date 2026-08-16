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
import 'package:mobile/features/sales_history/presentation/screens/sales_history_screen.dart';

class _FakeSaleRepository implements SaleRepository {
  _FakeSaleRepository(this.sales);

  final List<CompletedSale> sales;

  @override
  Future<CompletedSale> completeSale({
    required String id,
    required String storeId,
    required List<CartLine> lines,
    String? customerId,
  }) => throw UnimplementedError();

  @override
  Future<List<CompletedSale>> listCompletedSales() async => sales;

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

  @override
  Future<SaleDetail?> lookupSale({
    String? provisionalInvoiceNumber,
    String? canonicalInvoiceNumber,
  }) => throw UnimplementedError();

  @override
  Future<SaleDetail?> fetchRemoteSaleDetail(String id) => throw UnimplementedError();
}

Widget _wrap(List<CompletedSale> sales) {
  return ProviderScope(
    overrides: [
      saleRepositoryProvider.overrideWithValue(_FakeSaleRepository(sales)),
    ],
    child: const MaterialApp(home: SalesHistoryScreen()),
  );
}

void main() {
  testWidgets('renders "No sales yet" when the list is empty', (tester) async {
    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sales_history_empty')), findsOneWidget);
  });

  testWidgets('renders each sale\'s invoice number and total', (tester) async {
    await tester.pumpWidget(
      _wrap([
        CompletedSale(
          id: 'sale-1',
          provisionalInvoiceNumber: 'DEV001-2026-000001',
          grandTotalMinorUnits: 3500,
          completedAt: DateTime(2026, 8, 12, 14, 30),
        ),
        CompletedSale(
          id: 'sale-2',
          provisionalInvoiceNumber: 'DEV001-2026-000002',
          grandTotalMinorUnits: 500,
          completedAt: DateTime(2026, 8, 12, 15, 0),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sales_history_sale_sale-1')), findsOneWidget);
    expect(find.byKey(const Key('sales_history_sale_sale-2')), findsOneWidget);
    expect(find.text('DEV001-2026-000001'), findsOneWidget);
    expect(find.text('\u{20B9}35.00'), findsOneWidget);
    expect(find.byKey(const Key('sales_history_empty')), findsNothing);
  });
}
