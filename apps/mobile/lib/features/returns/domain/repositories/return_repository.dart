import '../entities/return_detail.dart';
import '../entities/return_summary.dart';

/// One requested line within a [ReturnRepository.createReturn] call.
class ReturnLineItemInput {
  const ReturnLineItemInput({required this.originalSaleLineItemId, required this.quantity});

  final String originalSaleLineItemId;
  final int quantity;
}

/// Abstract interface only, per mobile-structure.md §2.
/// docs/modules/returns/specification.md §1b.
abstract class ReturnRepository {
  /// Writes the return (and its line items) locally and enqueues a
  /// `return.create` sync operation, atomically — the same local-write-path
  /// discipline `CustomerRepository.createCustomer`/
  /// `SaleRepository.completeSale` already established. Idempotent on `id`.
  /// Refund amounts are always server-computed — never supplied here.
  Future<ReturnDetail> createReturn({
    required String id,
    required String originalSaleId,
    required List<ReturnLineItemInput> lineItems,
  });

  /// This device's own filed returns — a best-effort live refresh
  /// (`GET /returns`), then a read of the resulting local cache; an offline
  /// call still resolves with whatever's cached.
  Future<List<ReturnSummary>> listMine();

  /// The Manager/Owner approval queue (`GET /returns/approvals`) — same
  /// refresh-then-cache shape. Shown to every role (specification.md §1b);
  /// a non-Manager/Owner caller's own refresh simply fails and is swallowed
  /// by the caller of this method, the same honest-403 stance §1b
  /// establishes.
  Future<List<ReturnSummary>> listApprovals();

  /// A single return's full detail — the local cache first, a live
  /// `GET /returns/{id}` fetch-and-cache fallback if absent.
  Future<ReturnDetail?> getDetail(String id);

  /// Writes the local status transition and enqueues a `return.approve`
  /// sync operation, atomically. Idempotent no-op if already `completed`.
  Future<ReturnDetail> approveReturn(String id);

  /// Writes the local status transition and enqueues a `return.reject`
  /// sync operation, atomically. Idempotent no-op if already `rejected`.
  Future<ReturnDetail> rejectReturn(String id, String reason);
}
