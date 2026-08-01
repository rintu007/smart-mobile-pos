import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart';
import 'package:mobile/core/database/tables/stock_movements.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('schema opens with no error', () async {
    // A schema that only compiles is not the same claim as a schema that
    // opens — Sprint 02's "at least one real HTTP request" rule, applied to
    // the local database instead of an API endpoint.
    await db.customSelect('select 1').getSingle();
  });

  test('outbound_queue round-trips a queued operation', () async {
    await db.into(db.outboundQueue).insert(
          OutboundQueueCompanion.insert(
            clientOperationId: 'op-1',
            entityType: 'sale',
            payload: '{"foo":"bar"}',
          ),
        );

    final row = await (db.select(db.outboundQueue)
          ..where((t) => t.clientOperationId.equals('op-1')))
        .getSingle();

    expect(row.status, 'queued');
    expect(row.attemptCount, 0);
  });

  test('a sale with one line item and one cash payment round-trips', () async {
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: 'product-1',
            name: 'Test product',
            priceMinorUnits: 10000,
          ),
        );

    await db.into(db.sales).insert(
          SalesCompanion.insert(
            id: 'sale-1',
            status: 'completed',
            provisionalInvoiceNumber: 'PROV-0001',
            subtotalMinorUnits: 10000,
            grandTotalMinorUnits: 10000,
          ),
        );

    await db.into(db.saleLineItems).insert(
          SaleLineItemsCompanion.insert(
            id: 'line-1',
            saleId: 'sale-1',
            productId: 'product-1',
            quantity: 1,
            unitPriceMinorUnits: 10000,
            lineTotalMinorUnits: 10000,
          ),
        );

    await db.into(db.salePayments).insert(
          SalePaymentsCompanion.insert(
            id: 'payment-1',
            saleId: 'sale-1',
            method: 'cash',
            amountMinorUnits: 10000,
          ),
        );

    await db.into(db.stockMovements).insert(
          StockMovementsCompanion.insert(
            id: 'movement-1',
            productId: 'product-1',
            quantityDelta: -1,
            movementType: MovementType.sale,
            referenceType: const Value('sale'),
            referenceId: const Value('sale-1'),
          ),
        );

    final lineItems = await (db.select(db.saleLineItems)
          ..where((t) => t.saleId.equals('sale-1')))
        .get();
    final movements = await (db.select(db.stockMovements)
          ..where((t) => t.referenceId.equals('sale-1')))
        .get();

    expect(lineItems, hasLength(1));
    expect(movements, hasLength(1));
    expect(movements.single.movementType, MovementType.sale);
  });
}
