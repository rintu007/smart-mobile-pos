import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/invoicing/invoice_number_generator.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/entities/completed_sale.dart';
import '../../domain/repositories/sale_repository.dart';

/// Concrete implementation, per mobile-structure.md §2. Nothing here calls
/// the network directly — matches sync-architecture.md's "the local write
/// path is the one and only way any entity is created or changed on-device."
class DriftSaleRepository implements SaleRepository {
  DriftSaleRepository(this._db, this._invoiceNumbers);

  final AppDatabase _db;
  final InvoiceNumberGenerator _invoiceNumbers;

  @override
  Future<CompletedSale> completeSale({
    required String id,
    required String storeId,
    required List<CartLine> lines,
  }) {
    if (lines.isEmpty) {
      throw ArgumentError('A sale requires at least one line item.');
    }

    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.sales,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing != null) {
        return CompletedSale(
          id: existing.id,
          provisionalInvoiceNumber: existing.provisionalInvoiceNumber,
          grandTotalMinorUnits: existing.grandTotalMinorUnits,
        );
      }

      final grandTotalMinorUnits = lines.fold<int>(
        0,
        (sum, line) => sum + line.lineTotalMinorUnits,
      );
      final provisionalInvoiceNumber = await _invoiceNumbers.next();

      await _db
          .into(_db.sales)
          .insert(
            SalesCompanion.insert(
              id: id,
              status: 'completed',
              provisionalInvoiceNumber: provisionalInvoiceNumber,
              subtotalMinorUnits: grandTotalMinorUnits,
              grandTotalMinorUnits: grandTotalMinorUnits,
              completedAt: Value(DateTime.now()),
            ),
          );

      // Payload matches POST /api/v1/sales' own request shape exactly —
      // sync-api.md §1 — mirroring DriftProductRepository's precedent.
      final lineItemPayloads = <Map<String, Object?>>[];
      for (final line in lines) {
        await _db
            .into(_db.saleLineItems)
            .insert(
              SaleLineItemsCompanion.insert(
                id: const Uuid().v4(),
                saleId: id,
                productId: line.productId,
                quantity: line.quantity.toDouble(),
                unitPriceMinorUnits: line.unitPriceMinorUnits,
                lineTotalMinorUnits: line.lineTotalMinorUnits,
              ),
            );
        lineItemPayloads.add({
          'product_id': line.productId,
          'quantity': line.quantity,
          'client_unit_price_minor_units': line.unitPriceMinorUnits,
        });
      }

      await _db
          .into(_db.salePayments)
          .insert(
            SalePaymentsCompanion.insert(
              id: const Uuid().v4(),
              saleId: id,
              method: 'cash',
              amountMinorUnits: grandTotalMinorUnits,
            ),
          );

      final payload = jsonEncode({
        'id': id,
        'store_id': storeId,
        'provisional_invoice_number': provisionalInvoiceNumber,
        'line_items': lineItemPayloads,
        'payments': [
          {'method': 'cash', 'amount_minor_units': grandTotalMinorUnits},
        ],
      });
      await _db
          .into(_db.outboundQueue)
          .insert(
            OutboundQueueCompanion.insert(
              clientOperationId: id,
              entityType: 'sale.create',
              payload: payload,
            ),
          );

      return CompletedSale(
        id: id,
        provisionalInvoiceNumber: provisionalInvoiceNumber,
        grandTotalMinorUnits: grandTotalMinorUnits,
      );
    });
  }
}
