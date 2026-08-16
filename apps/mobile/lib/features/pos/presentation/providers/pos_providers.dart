import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../core/invoicing/invoice_number_generator.dart';
import '../../../../core/store_context/store_context_providers.dart';
import '../../../catalogue/domain/entities/product.dart';
import '../../../catalogue/presentation/providers/product_providers.dart';
import '../../data/data_sources/sales_api.dart' as sales_api;
import '../../data/repositories/drift_sale_repository.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/entities/completed_sale.dart';
import '../../domain/entities/held_sale.dart';
import '../../domain/entities/resumed_cart.dart';
import '../../domain/repositories/sale_repository.dart';

final productListProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).listAll();
});

/// FR-034 (search fallback for a product with no barcode) / FR-036 (category
/// filter) — both "Fully offline," so these filter the already-loaded local
/// list in memory rather than issuing a new query; a shop's product count is
/// small enough (catalogue.md's own "dozens, not thousands" reasoning) that
/// this needs no dedicated Drift search query. Plain `Notifier`, not
/// `StateProvider` — this codebase's Riverpod 3.x convention, same as
/// `CartController` below.
class PosSearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final posSearchQueryProvider = NotifierProvider<PosSearchQueryController, String>(
  PosSearchQueryController.new,
);

class PosCategoryFilterController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? categoryId) => state = categoryId;
}

final posCategoryFilterProvider =
    NotifierProvider<PosCategoryFilterController, String?>(PosCategoryFilterController.new);

final filteredProductListProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final productsAsync = ref.watch(productListProvider);
  final query = ref.watch(posSearchQueryProvider).trim().toLowerCase();
  final categoryId = ref.watch(posCategoryFilterProvider);

  return productsAsync.whenData(
    (products) => products.where((product) {
      final matchesQuery = query.isEmpty || product.name.toLowerCase().contains(query);
      final matchesCategory = categoryId == null || product.categoryId == categoryId;
      return matchesQuery && matchesCategory;
    }).toList(),
  );
});

final invoiceNumberGeneratorProvider = Provider<InvoiceNumberGenerator>((ref) {
  return InvoiceNumberGenerator(ref.watch(appDatabaseProvider));
});

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return DriftSaleRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(invoiceNumberGeneratorProvider),
    ({provisionalInvoiceNumber, canonicalInvoiceNumber}) => sales_api.fetchSaleByLookup(
      dio,
      provisionalInvoiceNumber: provisionalInvoiceNumber,
      canonicalInvoiceNumber: canonicalInvoiceNumber,
    ),
    (id) => sales_api.fetchSaleById(dio, id),
  );
});

/// The in-progress cart's state — `draftId` is `null` only when the cart is
/// empty (nothing to persist yet). Sprint 30 (backlog.md M2 item 6): the
/// cart is no longer purely in-memory — see `CartController`'s own
/// docstring. `customerId`/`customerName`/`customerPhone` added Sprint 32
/// (backlog.md M3 item 2) — the name/phone are a display snapshot, not a
/// live reference (avoids a provider round-trip on every till rebuild); the
/// id is the only field actually persisted/sent.
class CartState {
  const CartState({
    this.draftId,
    this.lines = const [],
    this.customerId,
    this.customerName,
    this.customerPhone,
  });

  final String? draftId;
  final List<CartLine> lines;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
}

/// The in-progress cart. Since Sprint 30 (Hold/Resume,
/// pos/specification.md §1/§2), continuously auto-persisted to the local
/// `sales`/`sale_line_items` tables on every mutation
/// (navigation-model.md §4) — not merely in-memory state that disappears
/// with the screen. Adding an already-present product increments its line's
/// quantity rather than duplicating a row.
class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  Future<void> addProduct(Product product) {
    final lines = state.lines;
    final index = lines.indexWhere((line) => line.productId == product.id);
    final updated = index == -1
        ? [
            ...lines,
            CartLine(
              productId: product.id,
              productName: product.name,
              unitPriceMinorUnits: product.priceMinorUnits,
              quantity: 1,
            ),
          ]
        : (List<CartLine>.from(lines)
            ..[index] = lines[index].copyWith(quantity: lines[index].quantity + 1));
    return _persist(updated);
  }

  /// Decrements a line's quantity, removing it entirely once it reaches
  /// zero.
  Future<void> decrementProduct(String productId) {
    final lines = state.lines;
    final index = lines.indexWhere((line) => line.productId == productId);
    if (index == -1) return Future.value();

    final line = lines[index];
    final updated = line.quantity <= 1
        ? (List<CartLine>.from(lines)..removeAt(index))
        : (List<CartLine>.from(lines)..[index] = line.copyWith(quantity: line.quantity - 1));
    return _persist(updated);
  }

  Future<void> _persist(List<CartLine> updatedLines) async {
    if (updatedLines.isEmpty) {
      final draftId = state.draftId;
      if (draftId != null) {
        await ref.read(saleRepositoryProvider).deleteDraft(draftId);
      }
      state = const CartState();
      return;
    }

    final draftId = state.draftId ?? const Uuid().v4();
    final storeId = await ref.read(storeContextProvider.future);
    await ref
        .read(saleRepositoryProvider)
        .saveDraft(
          id: draftId,
          storeId: storeId,
          lines: updatedLines,
          customerId: state.customerId,
        );
    state = CartState(
      draftId: draftId,
      lines: updatedLines,
      customerId: state.customerId,
      customerName: state.customerName,
      customerPhone: state.customerPhone,
    );
  }

  /// Attaches a customer to the active cart — `CustomerPickerSheet`'s
  /// result, per FR-050 (Sprint 32, backlog.md M3 item 2). If the cart
  /// already has a persisted draft row, re-persists immediately so the
  /// attachment survives hold/resume like every other cart field; if the
  /// cart is still empty (no draft row yet), only in-memory state is set —
  /// the attachment is carried along naturally once the first item's own
  /// `_persist` call creates the row.
  Future<void> attachCustomer({
    required String customerId,
    String? customerName,
    String? customerPhone,
  }) async {
    state = CartState(
      draftId: state.draftId,
      lines: state.lines,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
    );
    if (state.lines.isNotEmpty) {
      await _persist(state.lines);
    }
  }

  /// Detaches the active cart's customer, the mirror of [attachCustomer].
  Future<void> removeCustomer() async {
    state = CartState(draftId: state.draftId, lines: state.lines);
    if (state.lines.isNotEmpty) {
      await _persist(state.lines);
    }
  }

  /// WF-005 step 1 — holds the active cart (a no-op on an empty cart, which
  /// has nothing to hold) and clears it from the on-screen cart; the row
  /// itself stays in local storage as `status = 'held'`.
  Future<void> hold() async {
    final draftId = state.draftId;
    if (draftId == null || state.lines.isEmpty) return;
    await ref.read(saleRepositoryProvider).holdSale(draftId);
    state = const CartState();
  }

  /// WF-005 step 3 — loads a resumed held cart as the active one.
  /// pos/specification.md §2's resolved design decision: if a *different*
  /// cart is already active with items, it's implicitly held first, so
  /// nothing is silently discarded. Sprint 32: the resumed cart's attached
  /// customer (if any) is restored too, the same durability guarantee
  /// (FR-026) already applied to line items.
  Future<void> loadResumed(String id, ResumedCart resumed) async {
    final currentDraftId = state.draftId;
    if (currentDraftId != null && currentDraftId != id && state.lines.isNotEmpty) {
      await ref.read(saleRepositoryProvider).holdSale(currentDraftId);
    }
    state = CartState(
      draftId: id,
      lines: resumed.lines,
      customerId: resumed.customerId,
      customerName: resumed.customerName,
      customerPhone: resumed.customerPhone,
    );
  }

  /// Resets the in-memory cart only — used after `completeSale` has already
  /// transitioned the draft row to `completed` locally; there is no draft
  /// left to delete.
  void clear() => state = const CartState();
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

final cartGrandTotalProvider = Provider<int>((ref) {
  final lines = ref.watch(cartControllerProvider).lines;
  return lines.fold<int>(0, (sum, line) => sum + line.lineTotalMinorUnits);
});

/// Drives the till screen's "Complete sale" action — same `AsyncNotifier`
/// shape (and the same non-`async` `build()` fix) as
/// `SignInController`/`CreateProductController`.
class CompleteSaleController extends AsyncNotifier<CompletedSale?> {
  @override
  FutureOr<CompletedSale?> build() => null;

  Future<void> completeSale() async {
    final cart = ref.read(cartControllerProvider);
    if (cart.lines.isEmpty || cart.draftId == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final storeId = await ref.read(storeContextProvider.future);
      return ref
          .read(saleRepositoryProvider)
          .completeSale(
            id: cart.draftId!,
            storeId: storeId,
            lines: cart.lines,
            customerId: cart.customerId,
          );
    });

    if (!state.hasError) {
      ref.read(cartControllerProvider.notifier).clear();
    }
  }
}

final completeSaleControllerProvider =
    AsyncNotifierProvider<CompleteSaleController, CompletedSale?>(
      CompleteSaleController.new,
    );

/// The Held Carts list (`/pos/hold`) — WF-005 step 3.
final heldSalesListProvider = FutureProvider.autoDispose<List<HeldSale>>((ref) {
  return ref.watch(saleRepositoryProvider).listHeldSales();
});

/// Resumes a held cart by id, loading it into the active `CartController`
/// state. Returns `false` if `id` no longer exists/isn't held (defensive —
/// the UI should only ever call this with a valid id from
/// [heldSalesListProvider]'s own list). A plain function, not a
/// notifier/controller — `HeldCartsScreen` calls it directly and pops on
/// success, the same shape `TillScreen._scanBarcode` already established
/// for a one-shot async action with no state of its own worth tracking.
Future<bool> resumeHeldSale(WidgetRef ref, String id) async {
  final resumed = await ref.read(saleRepositoryProvider).resumeSale(id);
  if (resumed == null) return false;
  await ref.read(cartControllerProvider.notifier).loadResumed(id, resumed);
  return true;
}
