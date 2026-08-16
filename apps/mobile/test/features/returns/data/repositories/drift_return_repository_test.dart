import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart' hide ReturnLineItem;
import 'package:mobile/features/returns/data/repositories/drift_return_repository.dart';
import 'package:mobile/features/returns/domain/entities/return_detail.dart';
import 'package:mobile/features/returns/domain/entities/return_summary.dart';
import 'package:mobile/features/returns/domain/repositories/return_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  DriftReturnRepository buildRepository({
    Future<List<ReturnSummary>> Function()? fetchMine,
    Future<List<ReturnSummary>> Function()? fetchApprovals,
    Future<ReturnDetail?> Function(String)? fetchById,
  }) {
    return DriftReturnRepository(
      db,
      fetchMine ?? () async => [],
      fetchApprovals ?? () async => [],
      fetchById ?? (id) async => null,
    );
  }

  group('createReturn', () {
    test('writes the return, its line items, and enqueues a matching return.create operation', () async {
      final repository = buildRepository();

      final result = await repository.createReturn(
        id: 'return-1',
        originalSaleId: 'sale-1',
        lineItems: const [ReturnLineItemInput(originalSaleLineItemId: 'line-1', quantity: 1)],
      );

      expect(result.id, 'return-1');
      expect(result.originalSaleId, 'sale-1');

      final returnRow = await (db.select(
        db.returns,
      )..where((t) => t.id.equals('return-1'))).getSingle();
      expect(returnRow.originalSaleId, 'sale-1');

      final lineItemRows = await (db.select(
        db.returnLineItems,
      )..where((t) => t.returnId.equals('return-1'))).get();
      expect(lineItemRows, hasLength(1));
      expect(lineItemRows.single.originalSaleLineItemId, 'line-1');
      expect(lineItemRows.single.quantity, 1);

      final queueRow = await (db.select(
        db.outboundQueue,
      )..where((t) => t.clientOperationId.equals('return-1'))).getSingle();
      expect(queueRow.entityType, 'return.create');
      expect(queueRow.status, 'queued');
      expect(jsonDecode(queueRow.payload), {
        'id': 'return-1',
        'original_sale_id': 'sale-1',
        'line_items': [
          {'original_sale_line_item_id': 'line-1', 'quantity': 1},
        ],
      });
    });

    test('is idempotent: creating the same id twice writes only one row in each table', () async {
      final repository = buildRepository();
      const lineItems = [ReturnLineItemInput(originalSaleLineItemId: 'line-1', quantity: 1)];
      await repository.createReturn(id: 'return-1', originalSaleId: 'sale-1', lineItems: lineItems);

      final replay = await repository.createReturn(
        id: 'return-1',
        originalSaleId: 'sale-different', // A stale/differing retry payload.
        lineItems: lineItems,
      );

      expect(replay.originalSaleId, 'sale-1');
      final returnRows = await db.select(db.returns).get();
      final queueRows = await db.select(db.outboundQueue).get();
      expect(returnRows, hasLength(1));
      expect(queueRows, hasLength(1));
    });

    test('the write is atomic: a failed enqueue leaves no return row behind', () async {
      final repository = buildRepository();
      await db
          .into(db.outboundQueue)
          .insert(
            OutboundQueueCompanion.insert(
              clientOperationId: 'return-1',
              entityType: 'unrelated',
              payload: '{}',
            ),
          );

      await expectLater(
        () => repository.createReturn(
          id: 'return-1',
          originalSaleId: 'sale-1',
          lineItems: const [ReturnLineItemInput(originalSaleLineItemId: 'line-1', quantity: 1)],
        ),
        throwsA(anything),
      );

      final returnRows = await db.select(db.returns).get();
      expect(returnRows, isEmpty);
    });
  });

  group('listMine / listApprovals', () {
    test('upserts the live-fetched page into the cache without duplicating', () async {
      var callCount = 0;
      final summary = ReturnSummary(
        id: 'return-1',
        originalSaleId: 'sale-1',
        status: 'completed',
        refundTotalMinorUnits: 2800,
        createdAt: DateTime(2026, 8, 16),
      );
      final repository = buildRepository(
        fetchMine: () async {
          callCount++;
          return [summary];
        },
      );

      await repository.listMine();
      await repository.listMine();

      expect(callCount, 2);
      final rows = await db.select(db.returns).get();
      expect(rows, hasLength(1));
      expect(rows.single.refundTotalMinorUnits, 2800);
    });

    test('falls back to the cache when the injected fetch throws', () async {
      final repository = buildRepository(
        fetchMine: () async => throw Exception('offline'),
      );
      await db
          .into(db.returns)
          .insert(
            ReturnsCompanion.insert(
              id: 'return-1',
              originalSaleId: 'sale-1',
              status: 'completed',
              refundTotalMinorUnits: 2800,
            ),
          );

      final result = await repository.listMine();

      expect(result, hasLength(1));
      expect(result.single.id, 'return-1');
    });

    test(
      'a Cashier-style 403 on listApprovals is swallowed, resolving to whatever is cached (usually nothing)',
      () async {
        final repository = buildRepository(
          fetchApprovals: () async => throw Exception('403 PERMISSION_DENIED'),
        );

        final result = await repository.listApprovals();

        expect(result, isEmpty);
      },
    );
  });

  group('getDetail', () {
    test('prefers the local cache over a live fetch', () async {
      var fetchCalled = false;
      final repository = buildRepository(fetchById: (id) async {
        fetchCalled = true;
        return null;
      });
      await db
          .into(db.returns)
          .insert(
            ReturnsCompanion.insert(
              id: 'return-1',
              originalSaleId: 'sale-1',
              status: 'completed',
              refundTotalMinorUnits: 2800,
            ),
          );

      final result = await repository.getDetail('return-1');

      expect(result?.id, 'return-1');
      expect(fetchCalled, isFalse);
    });

    test('falls back to a live fetch and caches it when absent locally', () async {
      final repository = buildRepository(
        fetchById: (id) async => ReturnDetail(
          id: id,
          originalSaleId: 'sale-1',
          status: 'completed',
          refundTotalMinorUnits: 2800,
          createdAt: DateTime(2026, 8, 16),
          lineItems: const [
            ReturnLineItem(
              originalSaleLineItemId: 'line-1',
              quantity: 1,
              refundAmountMinorUnits: 2800,
            ),
          ],
        ),
      );

      final result = await repository.getDetail('return-remote');

      expect(result?.lineItems, hasLength(1));
      final cachedRow = await (db.select(
        db.returns,
      )..where((t) => t.id.equals('return-remote'))).getSingle();
      expect(cachedRow.refundTotalMinorUnits, 2800);
    });

    test('returns null when absent both locally and remotely', () async {
      final repository = buildRepository();
      expect(await repository.getDetail('missing'), isNull);
    });
  });

  group('approveReturn', () {
    test('updates the local row to completed and enqueues a matching return.approve operation', () async {
      final repository = buildRepository();
      await db
          .into(db.returns)
          .insert(
            ReturnsCompanion.insert(
              id: 'return-1',
              originalSaleId: 'sale-1',
              status: 'pending_approval',
              refundTotalMinorUnits: 2800,
            ),
          );

      final result = await repository.approveReturn('return-1');

      expect(result.status, 'completed');
      final row = await (db.select(
        db.returns,
      )..where((t) => t.id.equals('return-1'))).getSingle();
      expect(row.status, 'completed');
      expect(row.completedAt, isNotNull);

      final queueRows = await (db.select(
        db.outboundQueue,
      )..where((t) => t.entityType.equals('return.approve'))).get();
      expect(queueRows, hasLength(1));
      expect(jsonDecode(queueRows.single.payload), {'id': 'return-1'});
    });

    test('is an idempotent no-op on an already-completed return', () async {
      final repository = buildRepository();
      await db
          .into(db.returns)
          .insert(
            ReturnsCompanion.insert(
              id: 'return-1',
              originalSaleId: 'sale-1',
              status: 'completed',
              refundTotalMinorUnits: 2800,
            ),
          );

      await repository.approveReturn('return-1');

      final queueRows = await db.select(db.outboundQueue).get();
      expect(queueRows, isEmpty);
    });

    test('throws when the return is not cached locally', () async {
      final repository = buildRepository();
      await expectLater(() => repository.approveReturn('missing'), throwsArgumentError);
    });
  });

  group('rejectReturn', () {
    test('updates the local row to rejected and enqueues a matching return.reject operation', () async {
      final repository = buildRepository();
      await db
          .into(db.returns)
          .insert(
            ReturnsCompanion.insert(
              id: 'return-1',
              originalSaleId: 'sale-1',
              status: 'pending_approval',
              refundTotalMinorUnits: 2800,
            ),
          );

      final result = await repository.rejectReturn('return-1', 'Customer changed mind');

      expect(result.status, 'rejected');
      final queueRows = await (db.select(
        db.outboundQueue,
      )..where((t) => t.entityType.equals('return.reject'))).get();
      expect(queueRows, hasLength(1));
      expect(jsonDecode(queueRows.single.payload), {
        'id': 'return-1',
        'reason': 'Customer changed mind',
      });
    });

    test('is an idempotent no-op on an already-rejected return', () async {
      final repository = buildRepository();
      await db
          .into(db.returns)
          .insert(
            ReturnsCompanion.insert(
              id: 'return-1',
              originalSaleId: 'sale-1',
              status: 'rejected',
              refundTotalMinorUnits: 2800,
            ),
          );

      await repository.rejectReturn('return-1', 'reason');

      final queueRows = await db.select(db.outboundQueue).get();
      expect(queueRows, isEmpty);
    });
  });
}
