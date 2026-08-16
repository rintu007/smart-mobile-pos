import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart' hide ReturnLineItem;
import '../../domain/entities/return_detail.dart';
import '../../domain/entities/return_summary.dart';
import '../../domain/repositories/return_repository.dart';

/// Concrete implementation, per mobile-structure.md §2. The two network
/// reads (`_fetchMine`/`_fetchApprovals`/`_fetchById`) are injected as plain
/// functions, not a raw `Dio` — `DriftCustomerRepository`'s established
/// testability pattern. docs/modules/returns/specification.md §1b.
class DriftReturnRepository implements ReturnRepository {
  DriftReturnRepository(this._db, this._fetchMine, this._fetchApprovals, this._fetchById);

  final AppDatabase _db;
  final Future<List<ReturnSummary>> Function() _fetchMine;
  final Future<List<ReturnSummary>> Function() _fetchApprovals;
  final Future<ReturnDetail?> Function(String id) _fetchById;

  @override
  Future<ReturnDetail> createReturn({
    required String id,
    required String originalSaleId,
    required List<ReturnLineItemInput> lineItems,
  }) {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.returns,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing != null) {
        return _detailFor(existing);
      }

      // Refund amounts are never known locally — DR-014, always
      // server-computed. `0`/`pending_approval` are optimistic placeholders,
      // reconciled the next time this return is fetched (its own detail
      // screen, or the next `listMine`/`listApprovals` refresh) once the
      // sync-pushed `return.create` operation actually resolves.
      await _db
          .into(_db.returns)
          .insert(
            ReturnsCompanion.insert(
              id: id,
              originalSaleId: originalSaleId,
              status: 'pending_approval',
              refundTotalMinorUnits: 0,
            ),
          );

      final rowIds = <String>[];
      for (final item in lineItems) {
        final rowId = const Uuid().v4();
        rowIds.add(rowId);
        await _db
            .into(_db.returnLineItems)
            .insert(
              ReturnLineItemsCompanion.insert(
                id: rowId,
                returnId: id,
                originalSaleLineItemId: item.originalSaleLineItemId,
                quantity: item.quantity,
                refundAmountMinorUnits: 0,
              ),
            );
      }

      // Payload matches POST /api/v1/returns' own request shape exactly —
      // sync-api.md §1 — mirroring DriftCustomerRepository's precedent.
      final payload = jsonEncode({
        'id': id,
        'original_sale_id': originalSaleId,
        'line_items': lineItems
            .map(
              (item) => {
                'original_sale_line_item_id': item.originalSaleLineItemId,
                'quantity': item.quantity,
              },
            )
            .toList(),
      });
      await _db
          .into(_db.outboundQueue)
          .insert(
            OutboundQueueCompanion.insert(
              clientOperationId: id,
              entityType: 'return.create',
              payload: payload,
            ),
          );

      return ReturnDetail(
        id: id,
        originalSaleId: originalSaleId,
        status: 'pending_approval',
        refundTotalMinorUnits: 0,
        createdAt: DateTime.now(),
        lineItems: [
          for (var i = 0; i < lineItems.length; i++)
            ReturnLineItem(
              originalSaleLineItemId: lineItems[i].originalSaleLineItemId,
              quantity: lineItems[i].quantity,
              refundAmountMinorUnits: 0,
            ),
        ],
      );
    });
  }

  @override
  Future<List<ReturnSummary>> listMine() async {
    try {
      final fetched = await _fetchMine();
      await _cacheSummaries(fetched);
    } catch (_) {
      // Deliberately swallowed — falls back to the cache below, the same
      // best-effort-refresh shape `customerSearchResultsProvider` already
      // established.
    }
    return _readCachedSummaries();
  }

  @override
  Future<List<ReturnSummary>> listApprovals() async {
    try {
      final fetched = await _fetchApprovals();
      await _cacheSummaries(fetched);
    } catch (_) {
      // Deliberately swallowed — see `listMine`. Also the actual mechanism
      // behind "no badge for a Cashier" (specification.md §1b): a Cashier's
      // own `GET /returns/approvals` call 403s, is swallowed here, and this
      // method simply returns whatever (usually nothing) is already cached.
    }
    return _readCachedSummaries();
  }

  Future<void> _cacheSummaries(List<ReturnSummary> summaries) async {
    for (final summary in summaries) {
      await _db
          .into(_db.returns)
          .insertOnConflictUpdate(
            ReturnsCompanion(
              id: Value(summary.id),
              originalSaleId: Value(summary.originalSaleId),
              status: Value(summary.status),
              refundTotalMinorUnits: Value(summary.refundTotalMinorUnits),
              approvedBy: Value(summary.approvedBy),
              completedAt: Value(summary.completedAt),
              createdAt: Value(summary.createdAt),
            ),
          );
    }
  }

  Future<List<ReturnSummary>> _readCachedSummaries() async {
    final rows =
        await (_db.select(_db.returns)..orderBy([
              (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
            ]))
            .get();
    return rows.map(_summaryFor).toList();
  }

  @override
  Future<ReturnDetail?> getDetail(String id) async {
    final cached = await (_db.select(
      _db.returns,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (cached != null) return _detailFor(cached);

    final remote = await _fetchById(id);
    if (remote == null) return null;
    await _cacheDetail(remote);
    return remote;
  }

  Future<void> _cacheDetail(ReturnDetail detail) async {
    await _db.transaction(() async {
      await _db
          .into(_db.returns)
          .insertOnConflictUpdate(
            ReturnsCompanion(
              id: Value(detail.id),
              originalSaleId: Value(detail.originalSaleId),
              status: Value(detail.status),
              refundTotalMinorUnits: Value(detail.refundTotalMinorUnits),
              approvedBy: Value(detail.approvedBy),
              completedAt: Value(detail.completedAt),
              createdAt: Value(detail.createdAt),
            ),
          );
      await (_db.delete(
        _db.returnLineItems,
      )..where((t) => t.returnId.equals(detail.id))).go();
      for (final item in detail.lineItems) {
        await _db
            .into(_db.returnLineItems)
            .insert(
              ReturnLineItemsCompanion.insert(
                id: const Uuid().v4(),
                returnId: detail.id,
                originalSaleLineItemId: item.originalSaleLineItemId,
                quantity: item.quantity,
                refundAmountMinorUnits: item.refundAmountMinorUnits,
              ),
            );
      }
    });
  }

  @override
  Future<ReturnDetail> approveReturn(String id) {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.returns,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        throw ArgumentError('Return $id is not cached locally — refresh the approvals list first.');
      }
      if (existing.status == 'completed') {
        return _detailFor(existing);
      }

      final completedAt = DateTime.now();
      await (_db.update(
        _db.returns,
      )..where((t) => t.id.equals(id))).write(
        ReturnsCompanion(status: const Value('completed'), completedAt: Value(completedAt)),
      );

      await _db
          .into(_db.outboundQueue)
          .insert(
            OutboundQueueCompanion.insert(
              clientOperationId: const Uuid().v4(),
              entityType: 'return.approve',
              payload: jsonEncode({'id': id}),
            ),
          );

      final detail = await _detailFor(existing);
      return detail.copyWith(status: 'completed', completedAt: completedAt);
    });
  }

  @override
  Future<ReturnDetail> rejectReturn(String id, String reason) {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.returns,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        throw ArgumentError('Return $id is not cached locally — refresh the approvals list first.');
      }
      if (existing.status == 'rejected') {
        return _detailFor(existing);
      }

      await (_db.update(
        _db.returns,
      )..where((t) => t.id.equals(id))).write(const ReturnsCompanion(status: Value('rejected')));

      await _db
          .into(_db.outboundQueue)
          .insert(
            OutboundQueueCompanion.insert(
              clientOperationId: const Uuid().v4(),
              entityType: 'return.reject',
              payload: jsonEncode({'id': id, 'reason': reason}),
            ),
          );

      final detail = await _detailFor(existing);
      return detail.copyWith(status: 'rejected');
    });
  }

  ReturnSummary _summaryFor(Return row) {
    return ReturnSummary(
      id: row.id,
      originalSaleId: row.originalSaleId,
      status: row.status,
      refundTotalMinorUnits: row.refundTotalMinorUnits,
      approvedBy: row.approvedBy,
      completedAt: row.completedAt,
      createdAt: row.createdAt,
    );
  }

  Future<ReturnDetail> _detailFor(Return row) async {
    final lineItemRows = await (_db.select(
      _db.returnLineItems,
    )..where((t) => t.returnId.equals(row.id))).get();
    return ReturnDetail(
      id: row.id,
      originalSaleId: row.originalSaleId,
      status: row.status,
      refundTotalMinorUnits: row.refundTotalMinorUnits,
      approvedBy: row.approvedBy,
      completedAt: row.completedAt,
      createdAt: row.createdAt,
      lineItems: lineItemRows
          .map(
            (item) => ReturnLineItem(
              originalSaleLineItemId: item.originalSaleLineItemId,
              quantity: item.quantity,
              refundAmountMinorUnits: item.refundAmountMinorUnits,
            ),
          )
          .toList(),
    );
  }
}

extension on ReturnDetail {
  ReturnDetail copyWith({String? status, DateTime? completedAt}) {
    return ReturnDetail(
      id: id,
      originalSaleId: originalSaleId,
      status: status ?? this.status,
      refundTotalMinorUnits: refundTotalMinorUnits,
      approvedBy: approvedBy,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      lineItems: lineItems,
    );
  }
}
