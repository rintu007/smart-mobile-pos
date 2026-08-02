import '../entities/product.dart';

/// Abstract interface only, per mobile-structure.md §2.
abstract class ProductRepository {
  /// Writes the product locally and enqueues a `product.create` sync
  /// operation, atomically — per sync-architecture.md's "the local write
  /// path is the one and only way any entity is created or changed
  /// on-device." Idempotent on `id`: calling this again with an `id` that
  /// already exists locally is a no-op, matching the server endpoint's own
  /// idempotent-creation behaviour (ADR-0007).
  Future<Product> createProduct({
    required String id,
    required String name,
    required int priceMinorUnits,
  });
}
