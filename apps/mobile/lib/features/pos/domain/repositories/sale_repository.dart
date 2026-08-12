import '../entities/cart_line.dart';
import '../entities/completed_sale.dart';
import '../entities/sale_detail.dart';

/// Abstract interface only, per mobile-structure.md §2. Read methods added
/// Sprint 10 for `sales_history` — `pos` owns the `Sale` concept and its
/// local table, `sales_history` is a read-only UI layer on top (imported
/// directly rather than duplicating a parallel entity/repository, per
/// mobile-structure.md §3's guidance on cross-feature reuse).
abstract class SaleRepository {
  /// Writes the sale, its line items, and its single cash payment locally
  /// and enqueues a `sale.create` sync operation, atomically — same
  /// local-write-path discipline as `ProductRepository.createProduct`
  /// (sync-architecture.md's "the local write path is the one and only way
  /// any entity is created or changed on-device"). Idempotent on `id`.
  ///
  /// M0 scope only (pos/specification.md §2): the payment is always exactly
  /// the cart's grand total in cash — no tendered-amount/change-due
  /// tracking, no split payment.
  Future<CompletedSale> completeSale({
    required String id,
    required String storeId,
    required List<CartLine> lines,
  });

  /// This device's own completed sales, most-recent-first —
  /// sales-invoices/specification.md §2.
  Future<List<CompletedSale>> listCompletedSales();

  /// A single sale's line items, or `null` if `id` doesn't exist locally.
  Future<SaleDetail?> getSaleDetail(String id);
}
