import '../entities/unit.dart';

/// Abstract interface only, per mobile-structure.md §2.
abstract class UnitRepository {
  /// Same online-only, cache-after-success shape as
  /// `CategoryRepository.createCategory` — see that interface's own
  /// docstring for why. Idempotent on `id` (ADR-0007).
  Future<Unit> createUnit({
    required String id,
    required String name,
    required String symbol,
    required bool allowsFractional,
  });

  /// The local cache, name-ordered.
  Future<List<Unit>> listAll();

  /// Pulls this tenant's full unit list from the server and caches it.
  Future<void> refreshFromServer();
}
