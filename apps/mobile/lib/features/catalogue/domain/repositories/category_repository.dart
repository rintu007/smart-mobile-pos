import '../entities/category.dart';

/// Abstract interface only, per mobile-structure.md §2.
abstract class CategoryRepository {
  /// Calls the server directly (`POST /api/v1/categories`) and caches the
  /// result locally on success — **not** the queued local-write-first
  /// pattern `ProductRepository.createProduct` uses, because the sync engine
  /// has no `category.create` push operation type (only `product.create`/
  /// `sale.create` exist). A real, named gap against schema-local.md's "full
  /// local read/write copy" classification: creating a category requires
  /// connectivity. Idempotent on `id`, matching the server endpoint's own
  /// behaviour (ADR-0007).
  Future<Category> createCategory({required String id, required String name});

  /// The local cache, name-ordered — reflects whatever this device has
  /// created or last pulled via [refreshFromServer].
  Future<List<Category>> listAll();

  /// Pulls this tenant's full category list from the server and caches it.
  /// Categories.md's own note ("a shop has dozens, not thousands") is why
  /// this reads only the first page rather than walking every cursor.
  Future<void> refreshFromServer();
}
