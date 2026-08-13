/// One `outbound_queue` row, shaped for `POST /api/v1/sync/push` — matches
/// sync-api.md §1's operation envelope exactly.
class QueuedOperation {
  const QueuedOperation({
    required this.type,
    required this.clientOperationId,
    required this.payload,
  });

  final String type;
  final String clientOperationId;
  final Map<String, dynamic> payload;
}

/// One entry of `POST /sync/push`'s `results[]` — sync-api.md §3.
class SyncPushOperationResult {
  const SyncPushOperationResult({
    required this.clientOperationId,
    required this.status,
    this.errorCode,
    this.errorMessage,
  });

  final String clientOperationId;

  /// `'accepted'` or `'rejected'`.
  final String status;

  final String? errorCode;
  final String? errorMessage;

  bool get isAccepted => status == 'accepted';

  /// sync-api.md §4 — retryable, not a permanent rejection.
  bool get isDependencyPending => errorCode == 'DEPENDENCY_NOT_FOUND';
}

class SyncPushResponse {
  const SyncPushResponse(this.results);

  final List<SyncPushOperationResult> results;
}

/// One `products` row from `GET /sync/pull?entity_type=products`.
///
/// `categoryId`/`unitId`/`sku`/`barcode` added Sprint 21 — fixing a real gap
/// found while wiring the till's barcode-scan lookup: Sprint 20 added these
/// columns to both the server and local `products` tables, but this pull
/// response never carried them, so a product created on *another* device (or
/// directly against the server) pulled down with all four null regardless of
/// what the server actually held. Only this device's own locally-created
/// products ever had real values. Fixed in the same pass as the barcode
/// feature that made the gap visible, not left for a later sprint.
class PulledProduct {
  const PulledProduct({
    required this.id,
    required this.name,
    required this.priceMinorUnits,
    this.categoryId,
    this.unitId,
    this.sku,
    this.barcode,
  });

  final String id;
  final String name;
  final int priceMinorUnits;
  final String? categoryId;
  final String? unitId;
  final String? sku;
  final String? barcode;
}

class SyncPullPage {
  const SyncPullPage({required this.products, required this.nextCursor});

  final List<PulledProduct> products;
  final String? nextCursor;
}

/// The result of one `SyncRepository.syncNow()` call — what the UI shows.
class SyncRunSummary {
  const SyncRunSummary({
    required this.accepted,
    required this.pending,
    required this.rejected,
    required this.productsPulled,
  });

  final int accepted;
  final int pending;
  final int rejected;
  final int productsPulled;

  bool get hadNothingToPush => accepted == 0 && pending == 0 && rejected == 0;
}
