import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart' hide Product;
import 'package:mobile/core/sync/sync_dto.dart';
import 'package:mobile/core/sync/sync_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> enqueue({
    required String clientOperationId,
    required String entityType,
    String status = 'queued',
    int attemptCount = 0,
  }) {
    return db
        .into(db.outboundQueue)
        .insert(
          OutboundQueueCompanion.insert(
            clientOperationId: clientOperationId,
            entityType: entityType,
            payload: '{"id":"$clientOperationId"}',
            status: Value(status),
            attemptCount: Value(attemptCount),
          ),
        );
  }

  Future<OutboundQueueData> queueRow(String id) {
    return (db.select(
      db.outboundQueue,
    )..where((t) => t.clientOperationId.equals(id))).getSingle();
  }

  test('marks an accepted operation as synced', () async {
    await enqueue(clientOperationId: 'op-1', entityType: 'product.create');

    final repo = SyncRepository(
      db,
      (operations) async => SyncPushResponse([
        SyncPushOperationResult(clientOperationId: 'op-1', status: 'accepted'),
      ]),
      ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
    );

    final summary = await repo.syncNow();

    expect(summary.accepted, 1);
    expect(summary.pending, 0);
    expect(summary.rejected, 0);
    expect((await queueRow('op-1')).status, 'synced');
  });

  test(
    'marks a DEPENDENCY_NOT_FOUND rejection as failed_retrying and increments attemptCount',
    () async {
      await enqueue(clientOperationId: 'op-1', entityType: 'sale.create', attemptCount: 1);

      final repo = SyncRepository(
        db,
        (operations) async => SyncPushResponse([
          SyncPushOperationResult(
            clientOperationId: 'op-1',
            status: 'rejected',
            errorCode: 'DEPENDENCY_NOT_FOUND',
            errorMessage: 'Product not found.',
          ),
        ]),
        ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
      );

      final summary = await repo.syncNow();

      expect(summary.pending, 1);
      final row = await queueRow('op-1');
      expect(row.status, 'failed_retrying');
      expect(row.attemptCount, 2);
    },
  );

  test('marks a permanent rejection as rejected with a reason', () async {
    await enqueue(clientOperationId: 'op-1', entityType: 'product.create');

    final repo = SyncRepository(
      db,
      (operations) async => SyncPushResponse([
        SyncPushOperationResult(
          clientOperationId: 'op-1',
          status: 'rejected',
          errorCode: 'VALIDATION_FAILED',
          errorMessage: 'Bad payload.',
        ),
      ]),
      ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
    );

    await repo.syncNow();

    final row = await queueRow('op-1');
    expect(row.status, 'rejected');
    expect(row.rejectionReason, 'Bad payload.');
  });

  test('includes both queued and failed_retrying rows in the push batch', () async {
    await enqueue(clientOperationId: 'op-1', entityType: 'product.create');
    await enqueue(clientOperationId: 'op-2', entityType: 'sale.create', status: 'failed_retrying');
    await enqueue(clientOperationId: 'op-3', entityType: 'product.create', status: 'synced');

    var sentIds = <String>[];
    final repo = SyncRepository(
      db,
      (operations) async {
        sentIds = operations.map((op) => op.clientOperationId).toList();
        return SyncPushResponse(
          operations
              .map(
                (op) => SyncPushOperationResult(
                  clientOperationId: op.clientOperationId,
                  status: 'accepted',
                ),
              )
              .toList(),
        );
      },
      ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
    );

    await repo.syncNow();

    expect(sentIds, containsAll(['op-1', 'op-2']));
    expect(sentIds, isNot(contains('op-3')));
  });

  test('does not call push at all when nothing is queued', () async {
    var pushCalled = false;
    final repo = SyncRepository(
      db,
      (operations) async {
        pushCalled = true;
        return const SyncPushResponse([]);
      },
      ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
    );

    final summary = await repo.syncNow();

    expect(pushCalled, false);
    expect(summary.hadNothingToPush, true);
  });

  test('pulls products across multiple pages and upserts them locally', () async {
    var callCount = 0;
    final repo = SyncRepository(
      db,
      (operations) async => const SyncPushResponse([]),
      ({cursor}) async {
        callCount++;
        if (cursor == null) {
          return const SyncPullPage(
            products: [PulledProduct(id: 'p1', name: 'Coffee', priceMinorUnits: 1500)],
            nextCursor: 'cursor-1',
          );
        }
        return const SyncPullPage(
          products: [PulledProduct(id: 'p2', name: 'Sugar', priceMinorUnits: 500)],
          nextCursor: null,
        );
      },
    );

    final summary = await repo.syncNow();

    expect(callCount, 2);
    expect(summary.productsPulled, 2);
    final products = await db.select(db.products).get();
    expect(products.map((p) => p.id), containsAll(['p1', 'p2']));
  });

  test('pulling an already-cached product updates it rather than duplicating it', () async {
    await db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(id: 'p1', name: 'Old name', priceMinorUnits: 100),
        );

    final repo = SyncRepository(
      db,
      (operations) async => const SyncPushResponse([]),
      ({cursor}) async => const SyncPullPage(
        products: [PulledProduct(id: 'p1', name: 'New name', priceMinorUnits: 200)],
        nextCursor: null,
      ),
    );

    await repo.syncNow();

    final products = await db.select(db.products).get();
    expect(products, hasLength(1));
    expect(products.single.name, 'New name');
    expect(products.single.priceMinorUnits, 200);
  });
}
