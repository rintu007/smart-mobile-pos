import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/database.dart';
import 'sync_dto.dart';

/// Drains `outbound_queue` via `POST /sync/push`, then refreshes the local
/// `products` cache via `GET /sync/pull` — docs/modules/sync-engine/specification.md.
/// The network calls are injected (same reasoning `StoreContextRepository`
/// already established) so tests can fake them without a mocking package.
class SyncRepository {
  SyncRepository(this._db, this._pushOperations, this._pullProductsPage);

  final AppDatabase _db;
  final Future<SyncPushResponse> Function(List<QueuedOperation>) _pushOperations;
  final Future<SyncPullPage> Function({String? cursor}) _pullProductsPage;

  /// Pushes every queued/retrying operation, then pulls the full `products`
  /// list. No local pull cursor is persisted between calls — every call pages
  /// from the start; incremental/resumable pulling is a Phase 13 performance
  /// tuning decision (sync-api.md §6), not needed at M0's dataset size, and
  /// avoids a schema migration risk against the founder's already-installed,
  /// persistent app (docs/modules/sync-engine/specification.md §1).
  Future<SyncRunSummary> syncNow() async {
    final pushResult = await _pushQueuedOperations();
    final pulledCount = await _pullAllProducts();

    return SyncRunSummary(
      accepted: pushResult.accepted,
      pending: pushResult.pending,
      rejected: pushResult.rejected,
      productsPulled: pulledCount,
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
              ),
            );
        count++;
      }
      if (page.nextCursor == null) break;
      cursor = page.nextCursor;
    }

    return count;
  }
}

class _PushCounts {
  const _PushCounts(this.accepted, this.pending, this.rejected);

  final int accepted;
  final int pending;
  final int rejected;
}
