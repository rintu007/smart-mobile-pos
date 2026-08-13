import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
// `apiClientProvider` lives in store_context_providers.dart (the first
// feature to need a Dio client) — reused here, same as sync_providers.dart.
import '../../../../core/store_context/store_context_providers.dart';
import '../../data/data_sources/categories_api.dart' as api;
import '../../data/repositories/drift_category_repository.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';

/// Manual (non-code-generated) Riverpod syntax, matching `product_providers.dart`.
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return DriftCategoryRepository(
    ref.watch(appDatabaseProvider),
    ({required id, required name}) => api.createCategoryOnServer(dio, id: id, name: name),
    () => api.fetchCategories(dio),
  );
});

/// Cache-first, best-effort-refresh: a failed [CategoryRepository.refreshFromServer]
/// (offline, cold Supabase project) is swallowed so this still resolves with
/// whatever's cached — same "loading never network-gated" reasoning
/// state-presentation.md §1 states, and the same swallow-on-failure shape
/// `autoSyncOnStartProvider` already established.
final categoriesListProvider = FutureProvider<List<Category>>((ref) async {
  final repository = ref.watch(categoryRepositoryProvider);
  try {
    await repository.refreshFromServer();
  } catch (_) {
    // Deliberately swallowed — see docstring above.
  }
  return repository.listAll();
});

/// Drives the categories screen's create dialog — same `AsyncNotifier` shape
/// (and the same non-`async` `build()` fix) as `CreateProductController`.
class CreateCategoryController extends AsyncNotifier<Category?> {
  @override
  FutureOr<Category?> build() => null;

  Future<void> createCategory({required String name}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(categoryRepositoryProvider).createCategory(id: const Uuid().v4(), name: name),
    );
    if (!state.hasError) {
      ref.invalidate(categoriesListProvider);
    }
  }
}

final createCategoryControllerProvider =
    AsyncNotifierProvider<CreateCategoryController, Category?>(CreateCategoryController.new);
