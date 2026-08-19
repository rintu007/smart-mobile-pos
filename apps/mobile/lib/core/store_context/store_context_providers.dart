import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'store_context_api.dart' as api;
import 'store_context_repository.dart';

/// Sprint 56 (docs/11-api/authentication.md §4) — has no default implementation any more, the
/// same fail-fast shape `app/providers.dart`'s `appDatabaseProvider` already established: the real
/// client needs the resolved local device id (`ensureDeviceIdentity`, an async local-database
/// read) baked in as the `X-Device-Id` header on every request, which a synchronous `Provider`
/// can't resolve internally. `main.dart` overrides this after bootstrap resolves the device
/// identity; tests override `storeContextProvider`/`syncRepositoryProvider` directly instead
/// (this project's existing pattern), never actually reaching this provider.
final apiClientProvider = Provider<Dio>((ref) {
  throw StateError(
    'apiClientProvider has no default implementation and must be overridden: with a real client '
    'carrying the resolved device id in main.dart, or a fake repository override in tests.',
  );
});

final storeContextRepositoryProvider = Provider<StoreContextRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return StoreContextRepository(
    ref.watch(appDatabaseProvider),
    () => api.fetchStores(dio),
  );
});

/// Watched by the app shell right after sign-in — resolves once the
/// device's `store_id` is cached (fetching it first if this is the first
/// time). Loading/error states render exactly like `productCountProvider`'s
/// existing pattern on the home screen.
final storeContextProvider = FutureProvider<String>((ref) {
  return ref.watch(storeContextRepositoryProvider).ensureStoreContext();
});
