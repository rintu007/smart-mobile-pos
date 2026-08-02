import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart' hide Product;
import 'package:mobile/features/catalogue/data/repositories/drift_product_repository.dart';

void main() {
  late AppDatabase db;
  late DriftProductRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftProductRepository(db);
  });

  tearDown(() => db.close());

  test('writes the product and enqueues a matching product.create operation', () async {
    final product = await repository.createProduct(
      id: 'product-1',
      name: 'Filter coffee',
      priceMinorUnits: 1500,
    );

    expect(product.name, 'Filter coffee');
    expect(product.priceMinorUnits, 1500);

    final productRow = await (db.select(
      db.products,
    )..where((t) => t.id.equals('product-1'))).getSingle();
    expect(productRow.name, 'Filter coffee');
    expect(productRow.priceMinorUnits, 1500);

    final queueRow = await (db.select(
      db.outboundQueue,
    )..where((t) => t.clientOperationId.equals('product-1'))).getSingle();
    expect(queueRow.entityType, 'product.create');
    expect(queueRow.status, 'queued');
    expect(jsonDecode(queueRow.payload), {
      'id': 'product-1',
      'name': 'Filter coffee',
      'price_minor_units': 1500,
    });
  });

  test('is idempotent: creating the same id twice writes only one row in each table', () async {
    await repository.createProduct(
      id: 'product-1',
      name: 'Filter coffee',
      priceMinorUnits: 1500,
    );
    // A retry with the same id and even a different (stale) price should
    // return the original, not overwrite it or create a duplicate — same
    // idempotent-replay contract the server endpoint uses.
    final replay = await repository.createProduct(
      id: 'product-1',
      name: 'Filter coffee',
      priceMinorUnits: 9999,
    );

    expect(replay.priceMinorUnits, 1500);

    final productRows = await db.select(db.products).get();
    final queueRows = await db.select(db.outboundQueue).get();
    expect(productRows, hasLength(1));
    expect(queueRows, hasLength(1));
  });

  test('the write is atomic: a failed enqueue leaves no product row behind', () async {
    // Pre-seed a conflicting outbound_queue row with the id createProduct
    // will try to reuse as its clientOperationId, forcing that insert to
    // throw a primary-key-conflict inside the transaction.
    await db
        .into(db.outboundQueue)
        .insert(
          OutboundQueueCompanion.insert(
            clientOperationId: 'product-1',
            entityType: 'unrelated',
            payload: '{}',
          ),
        );

    await expectLater(
      () => repository.createProduct(
        id: 'product-1',
        name: 'Filter coffee',
        priceMinorUnits: 1500,
      ),
      throwsA(anything),
    );

    final productRows = await db.select(db.products).get();
    expect(productRows, isEmpty);
  });
}
