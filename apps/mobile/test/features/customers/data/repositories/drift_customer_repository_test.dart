import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart' hide Customer;
import 'package:mobile/features/customers/data/repositories/drift_customer_repository.dart';
import 'package:mobile/features/customers/domain/entities/customer.dart';
import 'package:mobile/features/pos/domain/entities/completed_sale.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  DriftCustomerRepository buildRepository({
    Future<List<Customer>> Function()? fetchAll,
    Future<List<CompletedSale>> Function(String)? fetchPurchaseHistory,
  }) {
    return DriftCustomerRepository(
      db,
      fetchAll ?? () async => [],
      fetchPurchaseHistory ?? (id) async => [],
    );
  }

  test('createCustomer writes the row and enqueues a matching customer.create operation', () async {
    final repository = buildRepository();

    final customer = await repository.createCustomer(
      id: 'customer-1',
      name: 'Ramesh Kumar',
      phone: '9876543210',
    );

    expect(customer.name, 'Ramesh Kumar');
    expect(customer.phone, '9876543210');

    final row = await (db.select(
      db.customers,
    )..where((t) => t.id.equals('customer-1'))).getSingle();
    expect(row.name, 'Ramesh Kumar');
    expect(row.phone, '9876543210');

    final queueRow = await (db.select(
      db.outboundQueue,
    )..where((t) => t.clientOperationId.equals('customer-1'))).getSingle();
    expect(queueRow.entityType, 'customer.create');
    expect(queueRow.status, 'queued');
    expect(jsonDecode(queueRow.payload), {
      'id': 'customer-1',
      'name': 'Ramesh Kumar',
      'phone': '9876543210',
    });
  });

  test('createCustomer omits name/phone from the payload when null, not as a literal null', () async {
    final repository = buildRepository();

    await repository.createCustomer(id: 'customer-1', phone: '9876543210');

    final queueRow = await (db.select(
      db.outboundQueue,
    )..where((t) => t.clientOperationId.equals('customer-1'))).getSingle();
    final payload = jsonDecode(queueRow.payload) as Map<String, dynamic>;
    expect(payload.containsKey('name'), isFalse);
    expect(payload['phone'], '9876543210');
  });

  test('is idempotent: creating the same id twice writes only one row in each table', () async {
    final repository = buildRepository();
    await repository.createCustomer(id: 'customer-1', name: 'Ramesh Kumar');

    // A retry with the same id and a different (stale) name should return
    // the original, not overwrite it or create a duplicate — same
    // idempotent-replay contract the server endpoint uses.
    final replay = await repository.createCustomer(id: 'customer-1', name: 'Someone Else');

    expect(replay.name, 'Ramesh Kumar');

    final customerRows = await db.select(db.customers).get();
    final queueRows = await db.select(db.outboundQueue).get();
    expect(customerRows, hasLength(1));
    expect(queueRows, hasLength(1));
  });

  test('the write is atomic: a failed enqueue leaves no customer row behind', () async {
    final repository = buildRepository();
    // Pre-seed a conflicting outbound_queue row with the id createCustomer
    // will try to reuse as its clientOperationId, forcing that insert to
    // throw a primary-key-conflict inside the transaction.
    await db
        .into(db.outboundQueue)
        .insert(
          OutboundQueueCompanion.insert(
            clientOperationId: 'customer-1',
            entityType: 'unrelated',
            payload: '{}',
          ),
        );

    await expectLater(
      () => repository.createCustomer(id: 'customer-1', phone: '9876543210'),
      throwsA(anything),
    );

    final customerRows = await db.select(db.customers).get();
    expect(customerRows, isEmpty);
  });

  test('searchByPhone matches a phone prefix', () async {
    final repository = buildRepository();
    await repository.createCustomer(id: 'customer-1', phone: '9876543210');
    await repository.createCustomer(id: 'customer-2', phone: '9111111111');

    final results = await repository.searchByPhone('987');

    expect(results, hasLength(1));
    expect(results.single.id, 'customer-1');
  });

  test('searchByPhone with an empty query returns every cached customer', () async {
    final repository = buildRepository();
    await repository.createCustomer(id: 'customer-1', phone: '9876543210');
    await repository.createCustomer(id: 'customer-2', name: 'No phone');

    final results = await repository.searchByPhone('');

    expect(results, hasLength(2));
  });

  test('findById returns null when not present locally', () async {
    final repository = buildRepository();

    expect(await repository.findById('missing'), isNull);
  });

  test('refreshFromServer upserts without duplicating', () async {
    var callCount = 0;
    final repository = buildRepository(
      fetchAll: () async {
        callCount++;
        return [const Customer(id: 'customer-1', name: 'Ramesh Kumar', phone: '9876543210')];
      },
    );

    await repository.refreshFromServer();
    await repository.refreshFromServer();

    expect(callCount, 2);
    final rows = await db.select(db.customers).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Ramesh Kumar');
  });

  test('getPurchaseHistory delegates to the injected fetch function', () async {
    final repository = buildRepository(
      fetchPurchaseHistory: (id) async => [
        CompletedSale(
          id: 'sale-1',
          provisionalInvoiceNumber: 'DEV001-2026-000001',
          grandTotalMinorUnits: 3500,
          completedAt: DateTime(2026, 8, 16),
        ),
      ],
    );

    final history = await repository.getPurchaseHistory('customer-1');

    expect(history, hasLength(1));
    expect(history.single.id, 'sale-1');
  });
}
