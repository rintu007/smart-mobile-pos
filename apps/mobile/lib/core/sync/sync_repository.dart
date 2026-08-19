import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables/stock_movements.dart' show MovementType, MovementTypeConverter;
import 'sync_dto.dart';

/// Drains `outbound_queue` via `POST /sync/push`, then refreshes the local
/// `products`/`stock_movements`/`sales`/`shop_settings` caches via `GET
/// /sync/pull` — docs/modules/sync-engine/specification.md.
/// `stock_movements`/`sales` added Sprint 36 (backlog.md M4 item 1);
/// `shop_settings` (the low-stock threshold) plus a Manager/Owner
/// permission probe (`canViewReports`) added Sprint 37 (M4 item 2) — Reports
/// reads from the local caches this fills. The network calls are injected
/// (same reasoning `StoreContextRepository` already established) so tests
/// can fake them without a mocking package.
class SyncRepository {
  /// The last two pull functions are optional, trailing positional params
  /// with safe no-op defaults — added Sprint 36 (backlog.md M4 item 1) —
  /// the same "avoid a mass test-signature rewrite" precedent Sprint 34's
  /// `DriftSaleRepository` already established, rather than breaking every
  /// existing 3-arg test call site.
  SyncRepository(
    this._db,
    this._pushOperations,
    this._pullProductsPage, [
    Future<StockMovementPullPage> Function({String? cursor})? pullStockMovementsPage,
    Future<SalePullPage> Function({String? cursor})? pullSalesPage,
    Future<PulledShopSettings?> Function()? pullShopSettings,
    Future<bool> Function()? probeCanViewReports,
  ]) : _pullStockMovementsPage = pullStockMovementsPage ?? _noPullStockMovements,
       _pullSalesPage = pullSalesPage ?? _noPullSales,
       _pullShopSettings = pullShopSettings ?? _noPullShopSettings,
       _probeCanViewReports = probeCanViewReports ?? _noProbeCanViewReports;

  final AppDatabase _db;
  final Future<SyncPushResponse> Function(List<QueuedOperation>) _pushOperations;
  final Future<SyncPullPage> Function({String? cursor}) _pullProductsPage;
  final Future<StockMovementPullPage> Function({String? cursor}) _pullStockMovementsPage;
  final Future<SalePullPage> Function({String? cursor}) _pullSalesPage;
  final Future<PulledShopSettings?> Function() _pullShopSettings;
  final Future<bool> Function() _probeCanViewReports;

  static Future<StockMovementPullPage> _noPullStockMovements({String? cursor}) async =>
      const StockMovementPullPage(movements: [], nextCursor: null, hasMore: false);

  static Future<SalePullPage> _noPullSales({String? cursor}) async =>
      const SalePullPage(sales: [], nextCursor: null, hasMore: false);

  static Future<PulledShopSettings?> _noPullShopSettings() async => null;

  static Future<bool> _noProbeCanViewReports() async => false;

  /// Pushes every queued/retrying operation, then pulls `products` (full
  /// re-pull every call, no persisted cursor — §2's own named trade-off,
  /// unchanged this sprint) and `stock_movements`/`sales` (Sprint 36,
  /// resumable via a persisted per-entity-type cursor — see
  /// `_pullAllStockMovements`/`_pullAllSales` below).
  Future<SyncRunSummary> syncNow() async {
    final pushResult = await _pushQueuedOperations();
    final pulledCount = await _pullAllProducts();
    final stockMovementsPulled = await _pullAllStockMovements();
    final salesPulled = await _pullAllSales();
    await _refreshShopSettingsCache();

    return SyncRunSummary(
      accepted: pushResult.accepted,
      pending: pushResult.pending,
      rejected: pushResult.rejected,
      productsPulled: pulledCount,
      stockMovementsPulled: stockMovementsPulled,
      salesPulled: salesPulled,
    );
  }

  Future<_PushCounts> _pushQueuedOperations() async {
    final rows = await (_db.select(_db.outboundQueue)..where(
      (t) => t.status.equals('queued') | t.status.equals('failed_retrying'),
    )).get();

    if (rows.isEmpty) return const _PushCounts(0, 0, 0);

    final operations = rows
        .map(
          (row) => QueuedOperation(
            type: row.entityType,
            clientOperationId: row.clientOperationId,
            payload: jsonDecode(row.payload) as Map<String, dynamic>,
          ),
        )
        .toList();

    final response = await _pushOperations(operations);
    final resultsById = {
      for (final result in response.results) result.clientOperationId: result,
    };

    var accepted = 0;
    var pending = 0;
    var rejected = 0;
    final now = DateTime.now();

    for (final row in rows) {
      final result = resultsById[row.clientOperationId];
      if (result == null) continue; // Server omitted this operation's result — leave queued as-is.

      if (result.isAccepted) {
        accepted++;
        await _updateQueueRow(
          row.clientOperationId,
          OutboundQueueCompanion(
            status: const Value('synced'),
            lastAttemptedAt: Value(now),
          ),
        );
      } else if (result.isDependencyPending) {
        pending++;
        await _updateQueueRow(
          row.clientOperationId,
          OutboundQueueCompanion(
            status: const Value('failed_retrying'),
            attemptCount: Value(row.attemptCount + 1),
            lastAttemptedAt: Value(now),
          ),
        );
      } else {
        rejected++;
        await _updateQueueRow(
          row.clientOperationId,
          OutboundQueueCompanion(
            status: const Value('rejected'),
            rejectionReason: Value(result.errorMessage ?? result.errorCode ?? 'Rejected'),
            lastAttemptedAt: Value(now),
          ),
        );
      }
    }

    return _PushCounts(accepted, pending, rejected);
  }

  Future<void> _updateQueueRow(String clientOperationId, OutboundQueueCompanion update) {
    return (_db.update(
      _db.outboundQueue,
    )..where((t) => t.clientOperationId.equals(clientOperationId))).write(update);
  }

  Future<int> _pullAllProducts() async {
    String? cursor;
    var count = 0;

    while (true) {
      final page = await _pullProductsPage(cursor: cursor);
      for (final product in page.products) {
        await _db
            .into(_db.products)
            .insertOnConflictUpdate(
              ProductsCompanion(
                id: Value(product.id),
                name: Value(product.name),
                priceMinorUnits: Value(product.priceMinorUnits),
                categoryId: Value(product.categoryId),
                unitId: Value(product.unitId),
                sku: Value(product.sku),
                barcode: Value(product.barcode),
              ),
            );
        count++;
      }
      if (page.nextCursor == null) break;
      cursor = page.nextCursor;
    }

    return count;
  }

  /// Sprint 36 (backlog.md M4 item 1). Resumes from the persisted
  /// `sync_cursors` row for `'stock_movements'`, pages until `hasMore` is
  /// false, then persists the last cursor seen — so a growing transaction
  /// history is never re-pulled from scratch on every sync, unlike
  /// `_pullAllProducts` above (a small, near-static catalogue, where that
  /// cost is negligible and a persisted cursor isn't worth the complexity).
  Future<int> _pullAllStockMovements() async {
    String? cursor = await _readCursor('stock_movements');
    var count = 0;

    while (true) {
      final page = await _pullStockMovementsPage(cursor: cursor);
      for (final movement in page.movements) {
        await _db
            .into(_db.stockMovements)
            .insertOnConflictUpdate(
              StockMovementsCompanion(
                id: Value(movement.id),
                productId: Value(movement.productId),
                quantityDelta: Value(movement.quantityDelta),
                movementType: Value(_movementTypeFromWire(movement.movementType)),
                createdAt: Value(movement.createdAt),
              ),
            );
        count++;
      }
      cursor = page.nextCursor;
      if (!page.hasMore) break;
    }

    await _writeCursor('stock_movements', cursor);
    await _pruneStaleStockMovements();
    return count;
  }

  /// Sprint 53 (docs/13-offline-sync/inbound-sync.md §4) — "a rolling window covering the current
  /// and prior financial year," decided there but never actually applied until now: the server
  /// pull above was unfiltered (fixed the same sprint, `sync/service.ts`'s own
  /// `stockMovementsRetentionCutoff`), and nothing ever removed a row locally once synced, so a
  /// device's local cache grew without bound regardless of what the server sent. Uses the
  /// device's own clock, not the server's — a deliberate, low-stakes choice: this only decides how
  /// much *already-synced* local history a device keeps around, never anything financially or
  /// causally significant (clock-and-ordering.md §2's "device time is fine for local-only
  /// purposes" rule), and matches this codebase's own existing
  /// `InvoiceNumberGenerator._financialYearFor` convention (local time, not UTC — a deliberate,
  /// pre-existing divergence from the server's UTC convention that this sprint doesn't touch).
  Future<void> _pruneStaleStockMovements() async {
    final now = DateTime.now();
    final currentFyStartYear = now.month >= 4 ? now.year : now.year - 1;
    final cutoff = DateTime(currentFyStartYear - 1, 4, 1);
    await (_db.delete(
      _db.stockMovements,
    )..where((t) => t.createdAt.isSmallerThanValue(cutoff))).go();
  }

  /// Sprint 36 (backlog.md M4 item 1). Same resumable-cursor shape as
  /// `_pullAllStockMovements`. Each pulled sale's line items are upserted
  /// into `SaleLineItems` right after their parent `Sales` row, in the same
  /// iteration — that FK must exist first regardless of transaction
  /// boundaries.
  Future<int> _pullAllSales() async {
    String? cursor = await _readCursor('sales');
    var count = 0;

    while (true) {
      final page = await _pullSalesPage(cursor: cursor);
      for (final sale in page.sales) {
        await _db
            .into(_db.sales)
            .insertOnConflictUpdate(
              SalesCompanion(
                id: Value(sale.id),
                status: Value(sale.status),
                provisionalInvoiceNumber: Value(sale.provisionalInvoiceNumber),
                subtotalMinorUnits: Value(sale.subtotalMinorUnits),
                grandTotalMinorUnits: Value(sale.grandTotalMinorUnits),
                completedAt: Value(sale.completedAt),
                createdAt: Value(sale.createdAt),
                customerId: Value(sale.customerId),
              ),
            );
        for (final item in sale.lineItems) {
          await _db
              .into(_db.saleLineItems)
              .insertOnConflictUpdate(
                SaleLineItemsCompanion(
                  id: Value(item.id),
                  saleId: Value(sale.id),
                  productId: Value(item.productId),
                  quantity: Value(item.quantity),
                  unitPriceMinorUnits: Value(item.unitPriceMinorUnits),
                  lineTotalMinorUnits: Value(item.lineTotalMinorUnits),
                ),
              );
        }
        count++;
      }
      cursor = page.nextCursor;
      if (!page.hasMore) break;
    }

    await _writeCursor('sales', cursor);
    return count;
  }

  /// Sprint 37 (backlog.md M4 item 2), extended Sprint 39 (M4 item 4) with
  /// `footerMessage`. `_pullShopSettings`/`_probeCanViewReports` never throw
  /// (both default to safe no-ops, and their real implementations in
  /// `sync_api.dart` swallow their own failures) — this always completes,
  /// writing whatever it learned into the single-row `ShopSettingsCache`. A
  /// `null` `settings` (no `shop_settings` row at all — a theoretical
  /// pre-Sprint-25 case) leaves both the threshold *and* the footer message
  /// untouched rather than overwriting a real cached value with nothing —
  /// but once `settings` is non-null, `footerMessage` is written exactly as
  /// pulled, `null` included: unlike the threshold (never legitimately
  /// absent once a row exists), "no footer configured" is a real, distinct
  /// state from "never synced," and must overwrite a stale cached value.
  Future<void> _refreshShopSettingsCache() async {
    final settings = await _pullShopSettings();
    final canViewReports = await _probeCanViewReports();

    await _db
        .into(_db.shopSettingsCache)
        .insertOnConflictUpdate(
          ShopSettingsCacheCompanion(
            id: const Value('current'),
            lowStockThresholdQuantity: settings == null
                ? const Value.absent()
                : Value(settings.lowStockThresholdQuantity),
            footerMessage: settings == null
                ? const Value.absent()
                : Value(settings.receiptFooterMessage),
            canViewReports: Value(canViewReports),
            fetchedAt: Value(DateTime.now()),
          ),
        );
  }

  MovementType _movementTypeFromWire(String wire) =>
      const MovementTypeConverter().fromSql(wire);

  Future<String?> _readCursor(String entityType) async {
    final row = await (_db.select(
      _db.syncCursors,
    )..where((t) => t.entityType.equals(entityType))).getSingleOrNull();
    return row?.cursor;
  }

  Future<void> _writeCursor(String entityType, String? cursor) {
    return _db
        .into(_db.syncCursors)
        .insertOnConflictUpdate(
          SyncCursorsCompanion(entityType: Value(entityType), cursor: Value(cursor)),
        );
  }
}

class _PushCounts {
  const _PushCounts(this.accepted, this.pending, this.rejected);

  final int accepted;
  final int pending;
  final int rejected;
}
