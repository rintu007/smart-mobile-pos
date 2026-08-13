import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/providers.dart';
// `apiClientProvider` lives in store_context_providers.dart — reused here,
// same as category_providers.dart/sync_providers.dart.
import '../../../../core/store_context/store_context_providers.dart';
import '../../data/data_sources/units_api.dart' as api;
import '../../data/repositories/drift_unit_repository.dart';
import '../../domain/entities/unit.dart';
import '../../domain/repositories/unit_repository.dart';

/// Manual (non-code-generated) Riverpod syntax, matching `category_providers.dart`.
final unitRepositoryProvider = Provider<UnitRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return DriftUnitRepository(
    ref.watch(appDatabaseProvider),
    ({required id, required name, required symbol, required allowsFractional}) =>
        api.createUnitOnServer(dio, id: id, name: name, symbol: symbol, allowsFractional: allowsFractional),
    () => api.fetchUnits(dio),
  );
});

/// Same cache-first, best-effort-refresh shape as `categoriesListProvider`.
final unitsListProvider = FutureProvider<List<Unit>>((ref) async {
  final repository = ref.watch(unitRepositoryProvider);
  try {
    await repository.refreshFromServer();
  } catch (_) {
    // Deliberately swallowed — see categoriesListProvider's docstring.
  }
  return repository.listAll();
});

/// Drives the units screen's create dialog — same shape as `CreateCategoryController`.
class CreateUnitController extends AsyncNotifier<Unit?> {
  @override
  FutureOr<Unit?> build() => null;

  Future<void> createUnit({
    required String name,
    required String symbol,
    required bool allowsFractional,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(unitRepositoryProvider)
          .createUnit(
            id: const Uuid().v4(),
            name: name,
            symbol: symbol,
            allowsFractional: allowsFractional,
          ),
    );
    if (!state.hasError) {
      ref.invalidate(unitsListProvider);
    }
  }
}

final createUnitControllerProvider = AsyncNotifierProvider<CreateUnitController, Unit?>(
  CreateUnitController.new,
);
