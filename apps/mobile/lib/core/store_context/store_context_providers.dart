import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../network/api_client.dart';
import 'store_context_api.dart' as api;
import 'store_context_repository.dart';

final apiClientProvider = Provider((ref) => buildApiClient());

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
