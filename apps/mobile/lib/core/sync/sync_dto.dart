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

/// One `stock_movements` row from `GET /sync/pull?entity_type=stock_movements`
/// — added Sprint 36 (backlog.md M4 item 1), the "reporting parity across
/// devices" pull sync-api.md §6 has named since Phase 11 and this sprint
/// finally implements. Reports (M4 item 2) computes stock value/low-stock
/// from the local cache this fills.
class PulledStockMovement {
  const PulledStockMovement({
    required this.id,
    required this.productId,
    required this.quantityDelta,
    required this.movementType,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final double quantityDelta;
  final String movementType;
  final DateTime createdAt;
}

/// Unlike [SyncPullPage] (products), this page carries `hasMore` as its own
/// field, distinct from `nextCursor` — `nextCursor` here is always the last
/// row actually seen (even on the final page), so `SyncRepository` can
/// persist it as the next sync cycle's resume point; `hasMore` alone signals
/// whether to keep paging within the current run. Products never needed this
/// distinction (its pull cursor still isn't persisted between runs at all,
/// docs/modules/sync-engine/specification.md §2's own named trade-off).
class StockMovementPullPage {
  const StockMovementPullPage({
    required this.movements,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<PulledStockMovement> movements;
  final String? nextCursor;
  final bool hasMore;
}

/// One line item of a `PulledSale` — mirrors `GET /sales/{id}`'s own
/// `line_items[]` shape, minus the discount/tax fields `SaleLineItems`
/// (local) has never stored (a real, separately-named gap, sales.dart's own
/// docstring) — unaffected by this sprint, which only adds read-cache rows.
class PulledSaleLineItem {
  const PulledSaleLineItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unitPriceMinorUnits,
    required this.lineTotalMinorUnits,
  });

  final String id;
  final String productId;
  final double quantity;
  final int unitPriceMinorUnits;
  final int lineTotalMinorUnits;
}

/// One `sales` row from `GET /sync/pull?entity_type=sales` — added Sprint 36
/// (backlog.md M4 item 1). Only the fields the local `Sales` table actually
/// has columns for are carried through (`discount_total_minor_units` etc.
/// stay server-only, the same named M2 gap `PulledSaleLineItem` restates).
class PulledSale {
  const PulledSale({
    required this.id,
    required this.status,
    required this.provisionalInvoiceNumber,
    required this.subtotalMinorUnits,
    required this.grandTotalMinorUnits,
    required this.completedAt,
    required this.createdAt,
    required this.customerId,
    required this.lineItems,
  });

  final String id;
  final String status;
  final String provisionalInvoiceNumber;
  final int subtotalMinorUnits;
  final int grandTotalMinorUnits;
  final DateTime? completedAt;
  final DateTime createdAt;
  final String? customerId;
  final List<PulledSaleLineItem> lineItems;
}

/// Same `nextCursor`-always-last-row / `hasMore` split as
/// [StockMovementPullPage], same reasoning.
class SalePullPage {
  const SalePullPage({required this.sales, required this.nextCursor, required this.hasMore});

  final List<PulledSale> sales;
  final String? nextCursor;
  final bool hasMore;
}

/// The result of `GET /sync/pull?entity_type=shop_settings` — added Sprint 37
/// (backlog.md M4 item 2). Deliberately minimal (only what Reports needs,
/// docs/modules/reports/specification.md §3) — `null` when the tenant
/// genuinely has no `shop_settings` row (a theoretical pre-Sprint-25 case).
class PulledShopSettings {
  const PulledShopSettings({required this.lowStockThresholdQuantity});

  final int lowStockThresholdQuantity;
}

/// The result of one `SyncRepository.syncNow()` call — what the UI shows.
class SyncRunSummary {
  const SyncRunSummary({
    required this.accepted,
    required this.pending,
    required this.rejected,
    required this.productsPulled,
    this.stockMovementsPulled = 0,
    this.salesPulled = 0,
  });

  final int accepted;
  final int pending;
  final int rejected;
  final int productsPulled;

  /// Added Sprint 36 (backlog.md M4 item 1). Defaulted so existing call
  /// sites/tests that only ever cared about products don't need updating.
  final int stockMovementsPulled;
  final int salesPulled;

  bool get hadNothingToPush => accepted == 0 && pending == 0 && rejected == 0;
}
