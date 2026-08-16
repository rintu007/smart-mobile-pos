import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart';
import 'package:mobile/core/invoicing/invoice_number_generator.dart';
import 'package:mobile/features/pos/data/repositories/drift_sale_repository.dart';
import 'package:mobile/features/pos/domain/entities/cart_line.dart';

void main() {
  late AppDatabase db;
  late DriftSaleRepository repository;

  const lines = [
    CartLine(
      productId: 'product-1',
      productName: 'Filter coffee',
      unitPriceMinorUnits: 1500,
      quantity: 2,
    ),
    CartLine(
      productId: 'product-2',
      productName: 'Sugar',
      unitPriceMinorUnits: 500,
      quantity: 1,
    ),
  ];

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftSaleRepository(db, InvoiceNumberGenerator(db));
  });

  tearDown(() => db.close());

  test(
    'writes the sale, its line items, its cash payment, and enqueues a matching sale.create operation',
    () async {
      final completed = await repository.completeSale(
        id: 'sale-1',
        storeId: 'store-1',
        lines: lines,
      );

      expect(completed.grandTotalMinorUnits, 3500); // 2*1500 + 1*500
      expect(completed.provisionalInvoiceNumber, isNotEmpty);

      final saleRow = await (db.select(
        db.sales,
      )..where((t) => t.id.equals('sale-1'))).getSingle();
      expect(saleRow.status, 'completed');
      expect(saleRow.subtotalMinorUnits, 3500);
      expect(saleRow.grandTotalMinorUnits, 3500);
      expect(saleRow.completedAt, isNotNull);

      final lineItemRows = await (db.select(
        db.saleLineItems,
      )..where((t) => t.saleId.equals('sale-1'))).get();
      expect(lineItemRows, hasLength(2));
      expect(
        lineItemRows.map((r) => r.lineTotalMinorUnits).toList()..sort(),
        [500, 3000],
      );

      final paymentRows = await (db.select(
        db.salePayments,
      )..where((t) => t.saleId.equals('sale-1'))).get();
      expect(paymentRows, hasLength(1));
      expect(paymentRows.single.method, 'cash');
      expect(paymentRows.single.amountMinorUnits, 3500);

      final queueRow = await (db.select(
        db.outboundQueue,
      )..where((t) => t.clientOperationId.equals('sale-1'))).getSingle();
      expect(queueRow.entityType, 'sale.create');
      final payload = jsonDecode(queueRow.payload) as Map<String, dynamic>;
      expect(payload['id'], 'sale-1');
      expect(payload['store_id'], 'store-1');
      expect(payload['provisional_invoice_number'], completed.provisionalInvoiceNumber);
      expect(payload['line_items'], hasLength(2));
      expect(payload['line_items'][0], {
        'product_id': 'product-1',
        'quantity': 2,
        'client_unit_price_minor_units': 1500,
      });
      expect(payload['payments'], [
        {'method': 'cash', 'amount_minor_units': 3500},
      ]);
    },
  );

  test('is idempotent: completing the same id twice writes only one row set', () async {
    await repository.completeSale(id: 'sale-1', storeId: 'store-1', lines: lines);
    final replay = await repository.completeSale(
      id: 'sale-1',
      storeId: 'store-1',
      // A different cart on replay should not change the already-completed sale.
      lines: const [
        CartLine(
          productId: 'product-3',
          productName: 'Tea',
          unitPriceMinorUnits: 999,
          quantity: 9,
        ),
      ],
    );

    expect(replay.grandTotalMinorUnits, 3500);

    final saleRows = await db.select(db.sales).get();
    final lineItemRows = await db.select(db.saleLineItems).get();
    final paymentRows = await db.select(db.salePayments).get();
    final queueRows = await db.select(db.outboundQueue).get();
    expect(saleRows, hasLength(1));
    expect(lineItemRows, hasLength(2));
    expect(paymentRows, hasLength(1));
    expect(queueRows, hasLength(1));
  });

  test('does not increment the invoice sequence on a replay', () async {
    await repository.completeSale(id: 'sale-1', storeId: 'store-1', lines: lines);
    await repository.completeSale(id: 'sale-1', storeId: 'store-1', lines: lines);

    final next = await repository.completeSale(
      id: 'sale-2',
      storeId: 'store-1',
      lines: lines,
    );
    expect(next.provisionalInvoiceNumber.split('-').last, '000002');
  });

  test(
    'the write is atomic: a failed enqueue leaves no sales/line-item/payment rows behind',
    () async {
      // Pre-seed a conflicting outbound_queue row with the id completeSale
      // will try to reuse as its clientOperationId, forcing that insert to
      // throw a primary-key-conflict inside the transaction — same
      // technique as DriftProductRepository's own atomicity test, extended
      // here to a multi-row write.
      await db
          .into(db.outboundQueue)
          .insert(
            OutboundQueueCompanion.insert(
              clientOperationId: 'sale-1',
              entityType: 'unrelated',
              payload: '{}',
            ),
          );

      await expectLater(
        () => repository.completeSale(id: 'sale-1', storeId: 'store-1', lines: lines),
        throwsA(anything),
      );

      final saleRows = await db.select(db.sales).get();
      final lineItemRows = await db.select(db.saleLineItems).get();
      final paymentRows = await db.select(db.salePayments).get();
      expect(saleRows, isEmpty);
      expect(lineItemRows, isEmpty);
      expect(paymentRows, isEmpty);

      // The invoice-number sequence increment must also roll back —
      // otherwise a failed sale would silently burn a gap in the sequence,
      // which ADR-0008 requires to be gapless.
      final sequenceRows = await db.select(db.localProvisionalSequence).get();
      expect(sequenceRows, isEmpty);
    },
  );

  test('rejects an empty cart', () async {
    expect(
      () => repository.completeSale(id: 'sale-1', storeId: 'store-1', lines: const []),
      throwsA(isA<ArgumentError>()),
    );
  });

  group('listCompletedSales', () {
    test('returns an empty list before any sale exists', () async {
      expect(await repository.listCompletedSales(), isEmpty);
    });

    test('returns completed sales most-recent-first', () async {
      await repository.completeSale(id: 'sale-1', storeId: 'store-1', lines: lines);
      await repository.completeSale(id: 'sale-2', storeId: 'store-1', lines: lines);
      // Back-to-back `DateTime.now()` calls can land in the same clock tick
      // on some platforms — set explicit, unambiguous timestamps rather than
      // rely on real-clock resolution to prove the ordering.
      await (db.update(db.sales)..where((t) => t.id.equals('sale-1'))).write(
        SalesCompanion(completedAt: Value(DateTime(2026, 1, 1))),
      );
      await (db.update(db.sales)..where((t) => t.id.equals('sale-2'))).write(
        SalesCompanion(completedAt: Value(DateTime(2026, 1, 2))),
      );

      final result = await repository.listCompletedSales();
      expect(result.map((s) => s.id).toList(), ['sale-2', 'sale-1']);
    });
  });

  group('getSaleDetail', () {
    test('returns null for an id that does not exist locally', () async {
      expect(await repository.getSaleDetail('missing'), isNull);
    });

    test('returns every line item, with the product name looked up locally', () async {
      await db
          .into(db.products)
          .insert(
            ProductsCompanion.insert(
              id: 'product-1',
              name: 'Filter coffee',
              priceMinorUnits: 1500,
            ),
          );
      // product-2 ("Sugar") deliberately not inserted locally, to prove the
      // fallback path.
      await repository.completeSale(id: 'sale-1', storeId: 'store-1', lines: lines);

      final detail = await repository.getSaleDetail('sale-1');

      expect(detail, isNotNull);
      expect(detail!.grandTotalMinorUnits, 3500);
      expect(detail.lines, hasLength(2));

      final coffeeLine = detail.lines.firstWhere((l) => l.productId == 'product-1');
      expect(coffeeLine.productName, 'Filter coffee');
      expect(coffeeLine.lineTotalMinorUnits, 3000);

      final sugarLine = detail.lines.firstWhere((l) => l.productId == 'product-2');
      expect(sugarLine.productName, isNull, reason: 'product-2 was never cached locally');
      expect(sugarLine.lineTotalMinorUnits, 500);
    });
  });

  // Sprint 30 (backlog.md M2 item 6, Hold/Resume) — pos/specification.md §1/§2.
  group('saveDraft', () {
    test('creates a draft row with a real provisional invoice number', () async {
      await repository.saveDraft(id: 'sale-1', storeId: 'store-1', lines: lines);

      final row = await (db.select(
        db.sales,
      )..where((t) => t.id.equals('sale-1'))).getSingle();
      expect(row.status, 'draft');
      expect(row.provisionalInvoiceNumber, isNotEmpty);
      expect(row.grandTotalMinorUnits, 3500);
      expect(row.completedAt, isNull);
      expect(row.createdAt, isNotNull);
    });

    test(
      'a second call updates the same row in place, never inserting a second row',
      () async {
        await repository.saveDraft(id: 'sale-1', storeId: 'store-1', lines: lines);
        final first = await (db.select(
          db.sales,
        )..where((t) => t.id.equals('sale-1'))).getSingle();

        await repository.saveDraft(
          id: 'sale-1',
          storeId: 'store-1',
          lines: const [
            CartLine(
              productId: 'product-1',
              productName: 'Filter coffee',
              unitPriceMinorUnits: 1500,
              quantity: 3,
            ),
          ],
        );

        final rows = await db.select(db.sales).get();
        expect(rows, hasLength(1));
        expect(rows.single.provisionalInvoiceNumber, first.provisionalInvoiceNumber);
        expect(rows.single.grandTotalMinorUnits, 4500);

        final lineItemRows = await (db.select(
          db.saleLineItems,
        )..where((t) => t.saleId.equals('sale-1'))).get();
        expect(lineItemRows, hasLength(1));
        expect(lineItemRows.single.quantity, 3);
      },
    );

    test('rejects an empty cart', () async {
      expect(
        () => repository.saveDraft(id: 'sale-1', storeId: 'store-1', lines: const []),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('deleteDraft', () {
    test('removes the draft row and its line items', () async {
      await repository.saveDraft(id: 'sale-1', storeId: 'store-1', lines: lines);

      await repository.deleteDraft('sale-1');

      expect(await db.select(db.sales).get(), isEmpty);
      expect(await db.select(db.saleLineItems).get(), isEmpty);
    });

    test('is a no-op for an id that does not exist', () async {
      await repository.deleteDraft('missing');
      expect(await db.select(db.sales).get(), isEmpty);
    });
  });

  group('holdSale / resumeSale / listHeldSales', () {
    test('holdSale transitions draft -> held', () async {
      await repository.saveDraft(id: 'sale-1', storeId: 'store-1', lines: lines);

      await repository.holdSale('sale-1');

      final row = await (db.select(
        db.sales,
      )..where((t) => t.id.equals('sale-1'))).getSingle();
      expect(row.status, 'held');
    });

    test('resumeSale transitions held -> draft and returns the cart lines', () async {
      await repository.saveDraft(id: 'sale-1', storeId: 'store-1', lines: lines);
      await repository.holdSale('sale-1');

      final resumed = await repository.resumeSale('sale-1');

      expect(resumed, isNotNull);
      expect(resumed!.lines, hasLength(2));
      expect(
        resumed.lines.map((l) => l.productId).toSet(),
        {'product-1', 'product-2'},
      );
      final row = await (db.select(
        db.sales,
      )..where((t) => t.id.equals('sale-1'))).getSingle();
      expect(row.status, 'draft');
    });

    test('resumeSale returns null for an id that is not currently held', () async {
      await repository.saveDraft(id: 'sale-1', storeId: 'store-1', lines: lines);
      // Still 'draft', never held.
      expect(await repository.resumeSale('sale-1'), isNull);
      expect(await repository.resumeSale('missing'), isNull);
    });

    test('listHeldSales returns only held rows, most-recently-held first', () async {
      await repository.saveDraft(id: 'sale-1', storeId: 'store-1', lines: lines);
      await repository.holdSale('sale-1');
      await (db.update(db.sales)..where((t) => t.id.equals('sale-1'))).write(
        SalesCompanion(createdAt: Value(DateTime(2026, 1, 1))),
      );

      await repository.saveDraft(id: 'sale-2', storeId: 'store-1', lines: lines);
      await repository.holdSale('sale-2');
      await (db.update(db.sales)..where((t) => t.id.equals('sale-2'))).write(
        SalesCompanion(createdAt: Value(DateTime(2026, 1, 2))),
      );

      // A third, still-active draft must not appear in the held list.
      await repository.saveDraft(id: 'sale-3', storeId: 'store-1', lines: lines);

      final held = await repository.listHeldSales();

      expect(held.map((s) => s.id).toList(), ['sale-2', 'sale-1']);
      expect(held.first.itemCount, 2);
      expect(held.first.grandTotalMinorUnits, 3500);
    });
  });

  // Sprint 32 (backlog.md M3 item 2): the attached customer survives
  // hold/resume, the same durability guarantee FR-026 already requires for
  // line items.
  group('customerId', () {
    test('saveDraft persists the attached customer id', () async {
      await repository.saveDraft(
        id: 'sale-1',
        storeId: 'store-1',
        lines: lines,
        customerId: 'customer-1',
      );

      final row = await (db.select(
        db.sales,
      )..where((t) => t.id.equals('sale-1'))).getSingle();
      expect(row.customerId, 'customer-1');
    });

    test('resumeSale restores the attached customer\'s name/phone from the local cache', () async {
      await db
          .into(db.customers)
          .insert(
            CustomersCompanion.insert(
              id: 'customer-1',
              name: const Value('Ramesh Kumar'),
              phone: const Value('9876543210'),
            ),
          );
      await repository.saveDraft(
        id: 'sale-1',
        storeId: 'store-1',
        lines: lines,
        customerId: 'customer-1',
      );
      await repository.holdSale('sale-1');

      final resumed = await repository.resumeSale('sale-1');

      expect(resumed, isNotNull);
      expect(resumed!.customerId, 'customer-1');
      expect(resumed.customerName, 'Ramesh Kumar');
      expect(resumed.customerPhone, '9876543210');
    });

    test('resumeSale returns null customer fields when no customer is attached', () async {
      await repository.saveDraft(id: 'sale-1', storeId: 'store-1', lines: lines);
      await repository.holdSale('sale-1');

      final resumed = await repository.resumeSale('sale-1');

      expect(resumed!.customerId, isNull);
      expect(resumed.customerName, isNull);
    });

    test('completeSale persists the attached customer id and includes it in the payload', () async {
      await repository.completeSale(
        id: 'sale-1',
        storeId: 'store-1',
        lines: lines,
        customerId: 'customer-1',
      );

      final row = await (db.select(
        db.sales,
      )..where((t) => t.id.equals('sale-1'))).getSingle();
      expect(row.customerId, 'customer-1');

      final queueRow = await (db.select(
        db.outboundQueue,
      )..where((t) => t.clientOperationId.equals('sale-1'))).getSingle();
      expect(jsonDecode(queueRow.payload)['customer_id'], 'customer-1');
    });

    test('completeSale omits customer_id from the payload when none is attached', () async {
      await repository.completeSale(id: 'sale-1', storeId: 'store-1', lines: lines);

      final queueRow = await (db.select(
        db.outboundQueue,
      )..where((t) => t.clientOperationId.equals('sale-1'))).getSingle();
      final payload = jsonDecode(queueRow.payload) as Map<String, dynamic>;
      expect(payload.containsKey('customer_id'), isFalse);
    });
  });

  group('completeSale on an existing draft/held row', () {
    test(
      'transitions the existing row in place -- same id, same provisional number',
      () async {
        await repository.saveDraft(id: 'sale-1', storeId: 'store-1', lines: lines);
        final draft = await (db.select(
          db.sales,
        )..where((t) => t.id.equals('sale-1'))).getSingle();

        final completed = await repository.completeSale(
          id: 'sale-1',
          storeId: 'store-1',
          lines: lines,
        );

        expect(completed.provisionalInvoiceNumber, draft.provisionalInvoiceNumber);
        final rows = await db.select(db.sales).get();
        expect(rows, hasLength(1));
        expect(rows.single.status, 'completed');
        expect(rows.single.completedAt, isNotNull);
      },
    );

    test('completing a held cart works the same way', () async {
      await repository.saveDraft(id: 'sale-1', storeId: 'store-1', lines: lines);
      await repository.holdSale('sale-1');

      final completed = await repository.completeSale(
        id: 'sale-1',
        storeId: 'store-1',
        lines: lines,
      );

      expect(completed.grandTotalMinorUnits, 3500);
      final row = await (db.select(
        db.sales,
      )..where((t) => t.id.equals('sale-1'))).getSingle();
      expect(row.status, 'completed');
    });
  });
}
