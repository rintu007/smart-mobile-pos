import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../../../core/invoicing/invoice_number_generator.dart';
import '../../../../core/store_context/store_context_providers.dart';
import '../../../catalogue/domain/entities/product.dart';
import '../../../catalogue/presentation/providers/product_providers.dart';
import '../../data/repositories/drift_sale_repository.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/entities/completed_sale.dart';
import '../../domain/repositories/sale_repository.dart';

final productListProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).listAll();
});

final invoiceNumberGeneratorProvider = Provider<InvoiceNumberGenerator>((ref) {
  return InvoiceNumberGenerator(ref.watch(appDatabaseProvider));
});

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return DriftSaleRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(invoiceNumberGeneratorProvider),
  );
});

/// The in-progress cart — never persisted (pos/specification.md §2, no
/// hold/resume in M0). Adding an already-present product increments its
/// line's quantity rather than duplicating a row.
class CartController extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => const [];

  void addProduct(Product product) {
    final index = state.indexWhere((line) => line.productId == product.id);
    if (index == -1) {
      state = [
        ...state,
        CartLine(
          productId: product.id,
          productName: product.name,
          unitPriceMinorUnits: product.priceMinorUnits,
          quantity: 1,
        ),
      ];
      return;
    }

    final updated = [...state];
    updated[index] = updated[index].copyWith(
      quantity: updated[index].quantity + 1,
    );
    state = updated;
  }

  /// Decrements a line's quantity, removing it entirely once it reaches
  /// zero.
  void decrementProduct(String productId) {
    final index = state.indexWhere((line) => line.productId == productId);
    if (index == -1) return;

    final line = state[index];
    if (line.quantity <= 1) {
      state = [...state]..removeAt(index);
      return;
    }

    final updated = [...state];
    updated[index] = line.copyWith(quantity: line.quantity - 1);
    state = updated;
  }

  void clear() => state = const [];
}

final cartControllerProvider = NotifierProvider<CartController, List<CartLine>>(
  CartController.new,
);

final cartGrandTotalProvider = Provider<int>((ref) {
  final lines = ref.watch(cartControllerProvider);
  return lines.fold<int>(0, (sum, line) => sum + line.lineTotalMinorUnits);
});

/// Drives the till screen's "Complete sale" action — same `AsyncNotifier`
/// shape (and the same non-`async` `build()` fix) as
/// `SignInController`/`CreateProductController`.
class CompleteSaleController extends AsyncNotifier<CompletedSale?> {
  @override
  FutureOr<CompletedSale?> build() => null;

  Future<void> completeSale() async {
    final lines = ref.read(cartControllerProvider);
    if (lines.isEmpty) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final storeId = await ref.read(storeContextProvider.future);
      return ref
          .read(saleRepositoryProvider)
          .completeSale(id: const Uuid().v4(), storeId: storeId, lines: lines);
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
