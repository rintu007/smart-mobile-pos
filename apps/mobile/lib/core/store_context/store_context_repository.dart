import '../database/database.dart';
import 'store_summary.dart';

/// A local cache of "which store does this device belong to," per
/// `store_context.dart`'s docstring. `fetchStores` is injected (not a
/// concrete Dio call baked in here) so tests can fake the network call
/// without a mocking package — the same reasoning
/// `SignInController`/`CreateProductController` use dependency injection
/// via Riverpod's `ref.read`, just at the constructor level here since this
/// isn't itself a provider-driven controller.
class StoreContextRepository {
  StoreContextRepository(this._db, this._fetchStores);

  final AppDatabase _db;
  final Future<List<StoreSummary>> Function() _fetchStores;

  static const _rowId = 'current';

  /// `null` if nothing has been cached yet — callers decide whether that
  /// means "fetch it now" or "show a setup-required state."
  Future<String?> getCachedStoreId() async {
    final row = await (_db.select(
      _db.storeContext,
    )..where((t) => t.id.equals(_rowId))).getSingleOrNull();
    return row?.storeId;
  }

  /// Fetches from `GET /api/v1/stores` (via the injected callback) and
  /// caches the first result — V1 always has exactly one store per tenant
  /// (ADR-0003), so "first" is never an arbitrary choice. Overwrites any
  /// previously cached row: this is a cache refresh, not an idempotent
  /// creation like the products/sales local writes.
  Future<String> refreshFromServer() async {
    final stores = await _fetchStores();
    if (stores.isEmpty) {
      throw StateError('GET /api/v1/stores returned no stores for this tenant.');
    }
    final store = stores.first;

    await _db
        .into(_db.storeContext)
        .insertOnConflictUpdate(
          StoreContextCompanion.insert(
            id: _rowId,
            storeId: store.id,
            storeName: store.name,
          ),
        );

    return store.id;
  }

  /// Cache-first: returns the cached `store_id` if present, otherwise
  /// fetches and caches it — the one call the app shell needs after sign-in.
  Future<String> ensureStoreContext() async {
    final cached = await getCachedStoreId();
    if (cached != null) return cached;
    return refreshFromServer();
  }
}
