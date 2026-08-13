import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
import '../../data/repositories/drift_product_repository.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

/// Manual (non-code-generated) Riverpod syntax — see
/// authentication/presentation/providers/auth_providers.dart for why.
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return DriftProductRepository(ref.watch(appDatabaseProvider));
});

/// Drives the add-product screen's submit button — same `AsyncNotifier`
/// shape as `SignInController`, including the same "don't mark `build()`
/// `async`" fix from Sprint 06 (an `async` body always resolves via a
/// microtask, which would flash a loading state on screen load).
class CreateProductController extends AsyncNotifier<Product?> {
  @override
  FutureOr<Product?> build() => null;

  Future<void> createProduct({
    required String name,
    required int priceMinorUnits,
    required String categoryId,
    required String unitId,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(productRepositoryProvider)
          .createProduct(
            id: const Uuid().v4(),
            name: name,
            priceMinorUnits: priceMinorUnits,
            categoryId: categoryId,
            unitId: unitId,
          ),
    );
  }
}

final createProductControllerProvider =
    AsyncNotifierProvider<CreateProductController, Product?>(
      CreateProductController.new,
    );
