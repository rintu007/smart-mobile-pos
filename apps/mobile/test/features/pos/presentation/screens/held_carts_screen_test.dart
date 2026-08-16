import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/store_context/store_context_providers.dart';
import 'package:mobile/features/pos/domain/entities/cart_line.dart';
import 'package:mobile/features/pos/domain/entities/completed_sale.dart';
import 'package:mobile/features/pos/domain/entities/held_sale.dart';
import 'package:mobile/features/pos/domain/entities/sale_detail.dart';
import 'package:mobile/features/pos/domain/repositories/sale_repository.dart';
import 'package:mobile/features/pos/presentation/providers/pos_providers.dart';
import 'package:mobile/features/pos/presentation/screens/held_carts_screen.dart';

/// A fake, not a mock — same reasoning as this feature's other Fakes.
/// `resumeSale` and `listHeldSales` are the two methods this screen
/// actually exercises; the rest throw since nothing here calls them.
class _FakeSaleRepository implements SaleRepository {
  _FakeSaleRepository(this._held);

  final Map<String, List<CartLine>> _held;
  final List<String> resumedIds = [];

  @override
  Future<List<HeldSale>> listHeldSales() async {
    return _held.entries
        .map(
          (e) => HeldSale(
            id: e.key,
            provisionalInvoiceNumber: 'DEV001-2026-000001',
            itemCount: e.value.length,
            grandTotalMinorUnits: e.value.fold<int>(0, (s, l) => s + l.lineTotalMinorUnits),
            createdAt: DateTime(2026, 8, 12),
          ),
        )
        .toList();
  }

  @override
  Future<List<CartLine>?> resumeSale(String id) async {
    final lines = _held.remove(id);
    if (lines == null) return null;
    resumedIds.add(id);
    return lines;
  }

  @override
  Future<CompletedSale> completeSale({
    required String id,
    required String storeId,
    required List<CartLine> lines,
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
  }) => throw UnimplementedError();

  @override
  Future<void> deleteDraft(String id) => throw UnimplementedError();

  @override
  Future<void> holdSale(String id) => throw UnimplementedError();
}

const _coffeeLine = CartLine(
  productId: 'product-1',
  productName: 'Filter coffee',
  unitPriceMinorUnits: 1500,
  quantity: 1,
);

/// A real, minimal two-route `GoRouter` — `HeldCartsScreen` calls
/// `context.pop()` on a successful resume, which (unlike `Navigator.pop`)
/// requires an actual `GoRouter` in the widget tree, not just a bare
/// `MaterialApp(home: ...)` (this feature's other screen tests avoid the
/// issue by never actually tapping their own push-triggering buttons —
/// this screen's whole point is the pop, so it can't be sidestepped here).
GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/pos',
    routes: [
      GoRoute(path: '/pos', builder: (context, state) => const Scaffold(body: Text('Till'))),
      GoRoute(
        path: '/pos/hold',
        builder: (context, state) => const HeldCartsScreen(),
      ),
    ],
  );
}

Widget _wrap(SaleRepository repository, GoRouter router) {
  return ProviderScope(
    overrides: [
      saleRepositoryProvider.overrideWithValue(repository),
      storeContextProvider.overrideWith((ref) async => 'store-1'),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Pumps the app at `/pos` first, then pushes `/pos/hold` on top — a bare
/// `initialLocation: '/pos/hold'` (or pushing before the first pump) leaves
/// nothing on the router's own stack for `HeldCartsScreen`'s `context.pop()`
/// to pop back to (found live: the first version of this test threw
/// "There is nothing to pop", since `GoRouter.push` before the delegate has
/// attached to a running widget tree doesn't register).
Future<void> _pumpToHeldCarts(WidgetTester tester, SaleRepository repository) async {
  final router = _buildRouter();
  await tester.pumpWidget(_wrap(repository, router));
  await tester.pumpAndSettle();
  router.push('/pos/hold');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows an empty state when nothing is held', (tester) async {
    await _pumpToHeldCarts(tester, _FakeSaleRepository({}));

    expect(find.byKey(const Key('pos_held_carts_empty')), findsOneWidget);
  });

  testWidgets('auto-resumes and pops when exactly one cart is held', (tester) async {
    final repository = _FakeSaleRepository({
      'sale-1': const [_coffeeLine],
    });
    await _pumpToHeldCarts(tester, repository);

    expect(repository.resumedIds, ['sale-1']);
    // Popped back to /pos — the held-carts screen is no longer on screen.
    expect(find.byType(HeldCartsScreen), findsNothing);
  });

  testWidgets('shows a picker list when two or more carts are held', (tester) async {
    final repository = _FakeSaleRepository({
      'sale-1': const [_coffeeLine],
      'sale-2': const [_coffeeLine],
    });
    await _pumpToHeldCarts(tester, repository);

    expect(find.byKey(const Key('pos_held_carts_list')), findsOneWidget);
    expect(find.byKey(const Key('pos_held_cart_sale-1')), findsOneWidget);
    expect(find.byKey(const Key('pos_held_cart_sale-2')), findsOneWidget);
    expect(repository.resumedIds, isEmpty);
  });

  testWidgets('tapping an entry in the picker list resumes it and pops', (tester) async {
    final repository = _FakeSaleRepository({
      'sale-1': const [_coffeeLine],
      'sale-2': const [_coffeeLine],
    });
    await _pumpToHeldCarts(tester, repository);

    await tester.tap(find.byKey(const Key('pos_held_cart_sale-2')));
    await tester.pumpAndSettle();

    expect(repository.resumedIds, ['sale-2']);
    expect(find.byType(HeldCartsScreen), findsNothing);
  });
}
