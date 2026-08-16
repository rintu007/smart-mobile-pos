import '../../../pos/domain/entities/completed_sale.dart';
import '../entities/customer.dart';
import '../entities/customer_field_conflict.dart';

/// Abstract interface only, per mobile-structure.md §2. Reuses `pos`'s own
/// `CompletedSale` entity for purchase history rather than duplicating an
/// identically-shaped one — mobile-structure.md §3's explicit-reuse
/// guidance, the same precedent `pos` itself already set reusing
/// `catalogue`'s `Product`.
abstract class CustomerRepository {
  /// Writes the customer locally and enqueues a `customer.create` sync
  /// operation, atomically — the same local-write-path discipline
  /// `ProductRepository.createProduct` established (sync-architecture.md's
  /// "the local write path is the one and only way any entity is created or
  /// changed on-device"), **not** Categories/Units' online-only shape, since
  /// `customer.create` is a real sync-push operation type
  /// (docs/modules/customers/specification.md §1a). Idempotent on `id`.
  Future<Customer> createCustomer({
    required String id,
    String? name,
    String? phone,
  });

  /// The local cache, matched by a phone prefix (FR-052's "as-you-type"
  /// search) — empty `query` returns every cached customer, most-recently-
  /// updated first. Purely local, no network call, matching FR-052's own
  /// "Fully offline" classification.
  Future<List<Customer>> searchByPhone(String query);

  /// A single cached customer, or `null` if not present locally.
  Future<Customer?> findById(String id);

  /// Pulls this tenant's customer list from the server (first page only,
  /// matching Categories/Units' own "a shop has dozens, not thousands"
  /// precedent) and caches it — the local search cache's only refresh path,
  /// since no `customer` sync-pull entity type exists yet
  /// (docs/modules/customers/specification.md §1a).
  Future<void> refreshFromServer();

  /// `GET /customers/{id}/purchase-history` — live, on demand, no local
  /// cache (customers/specification.md §1a: FR-051's own offline
  /// classification doesn't require this to work fully offline the way
  /// FR-052's search does).
  Future<List<CompletedSale>> getPurchaseHistory(String customerId);

  /// Writes the local row and enqueues a `customer.update` sync operation,
  /// atomically — the same local-write-path discipline `createCustomer`
  /// already established. Always succeeds locally regardless of
  /// connectivity (docs/modules/customers/specification.md §1c/§7): the
  /// merge conflict, if any, is resolved server-side once the operation
  /// syncs. The pre-edit local row's own `name`/`phone`/`updatedAt` become
  /// the operation's `base_name`/`base_phone`/`base_updated_at` — the
  /// field-level 3-way merge's own required inputs (§1c).
  Future<Customer> updateCustomer({required String id, String? name, String? phone});

  /// `GET /customers/conflicts` — live, online-only (§1c: a Manager/Owner
  /// reviewing conflicts that may have originated on a different device
  /// already needs connectivity to see them). Shown to every role; a
  /// Cashier's own call surfaces the server's `403` as a plain error, per
  /// returns/specification.md §1b's already-established
  /// no-client-side-role-awareness stance.
  Future<List<CustomerFieldConflict>> listConflicts();

  /// `POST /customers/conflicts/{id}/resolve` — live, online-only, same
  /// reasoning as [listConflicts]. `resolvedValue` must equal one of the
  /// conflict's own two candidate values.
  Future<void> resolveConflict({required String conflictId, required String? resolvedValue});
}
