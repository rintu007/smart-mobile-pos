import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../store_context/store_context_providers.dart';
import 'sync_api.dart' as api;
// `apiClientProvider` lives in store_context_providers.dart (the first
// feature to need a Dio client) — reused here rather than duplicated.
import 'sync_dto.dart';
import 'sync_repository.dart';

final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return SyncRepository(
    ref.watch(appDatabaseProvider),
    (operations) => api.pushSyncOperations(dio, operations),
    ({cursor}) => api.pullProductsPage(dio, cursor: cursor),
    ({cursor}) => api.pullStockMovementsPage(dio, cursor: cursor),
    ({cursor}) => api.pullSalesPage(dio, cursor: cursor),
    () => api.pullShopSettings(dio),
    () => api.probeCanViewReports(dio),
  );
});

/// Drives a manual "Sync now" action — same `AsyncNotifier` shape (and the
/// same non-`async` `build()` fix) as `CompleteSaleController`.
class SyncController extends AsyncNotifier<SyncRunSummary?> {
  @override
  FutureOr<SyncRunSummary?> build() => null;

  Future<void> syncNow() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(syncRepositoryProvider).syncNow());
  }
}

final syncControllerProvider = AsyncNotifierProvider<SyncController, SyncRunSummary?>(
  SyncController.new,
);

/// Runs once per app session, right after the device's store context is
/// known — the same "fully ready" moment `storeContextProvider` itself marks.
/// A `FutureProvider` is cached until invalidated, which is exactly the
/// "automatic, once, on start" trigger this sprint's minimal cut uses
/// (sync-api.md §7's connectivity-listener/background-timer triggers are
/// deferred — docs/modules/sync-engine/specification.md §1). A failure here
/// is swallowed deliberately: an auto-sync that fails on launch (no
/// connectivity, a cold Supabase project) should not block the home screen —
/// the next launch, or a manual "Sync now" tap, retries it.
final autoSyncOnStartProvider = FutureProvider<void>((ref) async {
  await ref.watch(storeContextProvider.future);
  try {
    await ref.read(syncRepositoryProvider).syncNow();
  } catch (_) {
    // Deliberately swallowed — see docstring above.
  }
});
