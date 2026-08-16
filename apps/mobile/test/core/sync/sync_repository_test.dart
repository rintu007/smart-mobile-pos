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

  test('a pulled product carries category_id/unit_id/sku/barcode into the local cache (Sprint 21 fix)', () async {
    final repo = SyncRepository(
      db,
      (operations) async => const SyncPushResponse([]),
      ({cursor}) async => const SyncPullPage(
        products: [
          PulledProduct(
            id: 'p1',
            name: 'Amul Milk',
            priceMinorUnits: 2800,
            categoryId: 'cat-1',
            unitId: 'unit-1',
            sku: 'AML-500',
            barcode: '8901234567890',
          ),
        ],
        nextCursor: null,
      ),
    );

    await repo.syncNow();

    final product = await (db.select(
      db.products,
    )..where((t) => t.id.equals('p1'))).getSingle();
    expect(product.categoryId, 'cat-1');
    expect(product.unitId, 'unit-1');
    expect(product.sku, 'AML-500');
    expect(product.barcode, '8901234567890');
  });

  group('stock_movements pull (Sprint 36, backlog.md M4 item 1)', () {
    test('pulls stock movements across multiple pages and upserts them locally', () async {
      var callCount = 0;
      final repo = SyncRepository(
        db,
        (operations) async => const SyncPushResponse([]),
        ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
        ({cursor}) async {
          callCount++;
          if (cursor == null) {
            return StockMovementPullPage(
              movements: [
                PulledStockMovement(
                  id: 'm1',
                  productId: 'p1',
                  quantityDelta: -2,
                  movementType: 'sale',
                  createdAt: DateTime.utc(2026, 8, 1),
                ),
              ],
              nextCursor: 'cursor-1',
              hasMore: true,
            );
          }
          return StockMovementPullPage(
            movements: [
              PulledStockMovement(
                id: 'm2',
                productId: 'p1',
                quantityDelta: 10,
                movementType: 'adjustment',
                createdAt: DateTime.utc(2026, 8, 2),
              ),
            ],
            nextCursor: 'cursor-2',
            hasMore: false,
          );
        },
      );

      final summary = await repo.syncNow();

      expect(callCount, 2);
      expect(summary.stockMovementsPulled, 2);
      final movements = await db.select(db.stockMovements).get();
      expect(movements.map((m) => m.id), containsAll(['m1', 'm2']));
    });

    test('persists the last cursor seen and resumes from it on the next sync', () async {
      var receivedCursors = <String?>[];
      final repo = SyncRepository(
        db,
        (operations) async => const SyncPushResponse([]),
        ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
        ({cursor}) async {
          receivedCursors.add(cursor);
          return const StockMovementPullPage(
            movements: [],
            nextCursor: 'resume-here',
            hasMore: false,
          );
        },
      );

      await repo.syncNow();
      await repo.syncNow();

      // First call has no persisted cursor yet; the second call resumes from
      // what the first call's own final page reported.
      expect(receivedCursors, [null, 'resume-here']);
    });

    test('pulling an already-cached movement updates it rather than duplicating it', () async {
      final repo = SyncRepository(
        db,
        (operations) async => const SyncPushResponse([]),
        ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
        ({cursor}) async => StockMovementPullPage(
          movements: [
            PulledStockMovement(
              id: 'm1',
              productId: 'p1',
              quantityDelta: -2,
              movementType: 'sale',
              createdAt: DateTime.utc(2026, 8, 1),
            ),
          ],
          nextCursor: null,
          hasMore: false,
        ),
      );

      await repo.syncNow();
      await repo.syncNow();

      final movements = await db.select(db.stockMovements).get();
      expect(movements, hasLength(1));
    });
  });

  group('sales pull (Sprint 36, backlog.md M4 item 1)', () {
    test('pulls a sale together with its line items', () async {
      final repo = SyncRepository(
        db,
        (operations) async => const SyncPushResponse([]),
        ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
        null,
        ({cursor}) async => SalePullPage(
          sales: [
            PulledSale(
              id: 's1',
              status: 'completed',
              provisionalInvoiceNumber: 'DEV-2026-000001',
              subtotalMinorUnits: 1500,
              grandTotalMinorUnits: 1500,
              completedAt: DateTime.utc(2026, 8, 1),
              createdAt: DateTime.utc(2026, 8, 1),
              customerId: null,
              lineItems: const [
                PulledSaleLineItem(
                  id: 'li1',
                  productId: 'p1',
                  quantity: 2,
                  unitPriceMinorUnits: 750,
                  lineTotalMinorUnits: 1500,
                ),
              ],
            ),
          ],
          nextCursor: null,
          hasMore: false,
        ),
      );

      final summary = await repo.syncNow();

      expect(summary.salesPulled, 1);
      final sale = await (db.select(db.sales)..where((t) => t.id.equals('s1'))).getSingle();
      expect(sale.grandTotalMinorUnits, 1500);
      final lineItems = await (db.select(
        db.saleLineItems,
      )..where((t) => t.saleId.equals('s1'))).get();
      expect(lineItems, hasLength(1));
      expect(lineItems.single.productId, 'p1');
    });

    test('pulling an already-cached sale updates it rather than duplicating it', () async {
      Future<SalePullPage> page({String? cursor}) async => SalePullPage(
        sales: [
          PulledSale(
            id: 's1',
            status: 'completed',
            provisionalInvoiceNumber: 'DEV-2026-000001',
            subtotalMinorUnits: 1500,
            grandTotalMinorUnits: 1500,
            completedAt: DateTime.utc(2026, 8, 1),
            createdAt: DateTime.utc(2026, 8, 1),
            customerId: null,
            lineItems: const [],
          ),
        ],
        nextCursor: null,
        hasMore: false,
      );

      final repo = SyncRepository(
        db,
        (operations) async => const SyncPushResponse([]),
        ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
        null,
        page,
      );

      await repo.syncNow();
      await repo.syncNow();

      final sales = await db.select(db.sales).get();
      expect(sales, hasLength(1));
    });
  });

  group('shop_settings pull + Reports role probe (Sprint 37, backlog.md M4 item 2)', () {
    test('writes the pulled low-stock threshold and probe result into ShopSettingsCache', () async {
      final repo = SyncRepository(
        db,
        (operations) async => const SyncPushResponse([]),
        ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
        null,
        null,
        () async => const PulledShopSettings(lowStockThresholdQuantity: 8),
        () async => true,
      );

      await repo.syncNow();

      final cache = await (db.select(
        db.shopSettingsCache,
      )..where((t) => t.id.equals('current'))).getSingle();
      expect(cache.lowStockThresholdQuantity, 8);
      expect(cache.canViewReports, true);
    });

    test('a swallowed probe failure (false) does not throw and is written as-is', () async {
      final repo = SyncRepository(
        db,
        (operations) async => const SyncPushResponse([]),
        ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
        null,
        null,
        () async => const PulledShopSettings(lowStockThresholdQuantity: 5),
        () async => false,
      );

      await repo.syncNow();

      final cache = await (db.select(
        db.shopSettingsCache,
      )..where((t) => t.id.equals('current'))).getSingle();
      expect(cache.canViewReports, false);
    });

    test('a null shop_settings pull leaves a previously-cached threshold untouched', () async {
      await db
          .into(db.shopSettingsCache)
          .insert(
            ShopSettingsCacheCompanion.insert(
              id: 'current',
              lowStockThresholdQuantity: const Value(7),
            ),
          );

      final repo = SyncRepository(
        db,
        (operations) async => const SyncPushResponse([]),
        ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
        null,
        null,
        () async => null,
        () async => true,
      );

      await repo.syncNow();

      final cache = await (db.select(
        db.shopSettingsCache,
      )..where((t) => t.id.equals('current'))).getSingle();
      expect(cache.lowStockThresholdQuantity, 7);
      expect(cache.canViewReports, true);
    });

    test('every pre-existing 3-through-5-arg constructor call site still works unchanged', () async {
      // No 6th/7th arg supplied at all — defaults to a no-op pull and a false probe,
      // never throwing, matching every earlier optional-trailing-param precedent.
      final repo = SyncRepository(
        db,
        (operations) async => const SyncPushResponse([]),
        ({cursor}) async => const SyncPullPage(products: [], nextCursor: null),
      );

      await repo.syncNow();

      final cache = await (db.select(
        db.shopSettingsCache,
      )..where((t) => t.id.equals('current'))).getSingle();
      expect(cache.lowStockThresholdQuantity, null);
      expect(cache.canViewReports, false);
    });
  });
}
