import '../entities/cart_line.dart';
import '../entities/completed_sale.dart';
import '../entities/held_sale.dart';
import '../entities/resumed_cart.dart';
import '../entities/sale_detail.dart';

/// Abstract interface only, per mobile-structure.md §2. Read methods added
/// Sprint 10 for `sales_history` — `pos` owns the `Sale` concept and its
/// local table, `sales_history` is a read-only UI layer on top (imported
/// directly rather than duplicating a parallel entity/repository, per
/// mobile-structure.md §3's guidance on cross-feature reuse). Hold/Resume
/// methods added Sprint 30 (backlog.md M2 item 6) — pos/specification.md §1/§2.
abstract class SaleRepository {
  /// Writes the sale, its line items, and its payment(s) locally and
  /// enqueues a `sale.create` sync operation, atomically — same
  /// local-write-path discipline as `ProductRepository.createProduct`
  /// (sync-architecture.md's "the local write path is the one and only way
  /// any entity is created or changed on-device."). Idempotent on `id`.
  ///
  /// Since Sprint 30, `id` is normally an existing `draft`/`held` row's own
  /// id (continuously auto-persisted as the cart was built) — this call
  /// transitions it to `completed` in place rather than inserting a fresh
  /// row, preserving the one provisional invoice number assigned at the
  /// cart's own creation (pos/specification.md §1's third design decision).
  /// Still handles the case where no such row exists (e.g. a direct test
  /// call) by inserting one.
  ///
  /// M0 scope only (pos/specification.md §2): the payment is always exactly
  /// the cart's grand total in cash — no tendered-amount/change-due
  /// tracking, no split payment (Split Payment is M2 item 5, server-only so
  /// far — not yet reflected in this mobile write path, a named gap).
  Future<CompletedSale> completeSale({
    required String id,
    required String storeId,
    required List<CartLine> lines,
    String? customerId,
  });

  /// This device's own completed sales, most-recent-first —
  /// sales-invoices/specification.md §2.
  Future<List<CompletedSale>> listCompletedSales();

  /// A single sale's line items, or `null` if `id` doesn't exist locally.
  Future<SaleDetail?> getSaleDetail(String id);

  /// Sprint 30 — keeps the active cart's local `draft` row in sync with
  /// `CartController`'s in-memory state on every mutation
  /// (navigation-model.md §4's continuous-auto-persistence requirement).
  /// Creates the row (and assigns its provisional invoice number) on the
  /// first call for a given `id`; every later call replaces its line items
  /// and recomputes its totals in place. `lines` must be non-empty — an
  /// empty cart has nothing to persist (see [deleteDraft]).
  Future<void> saveDraft({
    required String id,
    required String storeId,
    required List<CartLine> lines,
    String? customerId,
  });

  /// Deletes a `draft` row entirely — called when the last line item is
  /// removed from the active cart (an empty cart has nothing to hold or
  /// resume). A no-op if `id` doesn't exist.
  Future<void> deleteDraft(String id);

  /// WF-005 step 1 — transitions `draft -> held` (Sale state machine). The
  /// row and its line items are otherwise untouched.
  Future<void> holdSale(String id);

  /// WF-005 step 3 — transitions `held -> draft` and returns the cart's own
  /// line items plus its attached customer, if any (Sprint 32), ready to
  /// load back into `CartController`. Returns `null` if `id` doesn't exist
  /// or isn't currently `held`.
  Future<ResumedCart?> resumeSale(String id);

  /// The Held Carts list (`/pos/hold`), most-recently-held first.
  Future<List<HeldSale>> listHeldSales();
}
