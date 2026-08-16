import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/invoicing/invoice_number_generator.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/entities/completed_sale.dart';
import '../../domain/entities/held_sale.dart';
import '../../domain/entities/resumed_cart.dart';
import '../../domain/entities/sale_detail.dart';
import '../../domain/repositories/sale_repository.dart';

/// Concrete implementation, per mobile-structure.md §2. Writes never call the
/// network directly — matches sync-architecture.md's "the local write path
/// is the one and only way any entity is created or changed on-device." The
/// two new Sprint 34 reads (`lookupSale`/`fetchRemoteSaleDetail`) are a
/// deliberate exception — reading *any* sale under the tenant (not just this
/// device's own) has no local source of truth to fall back on for a sale
/// this device never wrote, the same reasoning `CustomerRepository`'s own
/// network reads already established. Both are injected as plain functions,
/// not a raw `Dio` — `DriftCustomerRepository`'s established testability
/// pattern.
class DriftSaleRepository implements SaleRepository {
  /// The two network functions are optional, defaulting to "always
  /// unresolved" — deliberately, so every existing call site/test
  /// constructing `DriftSaleRepository(db, invoiceNumbers)` for
  /// write-path/local-read behaviour (the overwhelming majority) keeps
  /// working unchanged; only a test that actually exercises
  /// `lookupSale`/`fetchRemoteSaleDetail` needs to supply them.
  DriftSaleRepository(
    this._db,
    this._invoiceNumbers, [
    Future<SaleDetail?> Function({String? provisionalInvoiceNumber, String? canonicalInvoiceNumber})?
    lookupSaleRemote,
    Future<SaleDetail?> Function(String id)? fetchSaleByIdRemote,
  ]) : _lookupSaleRemote = lookupSaleRemote ?? (({provisionalInvoiceNumber, canonicalInvoiceNumber}) async => null),
       _fetchSaleByIdRemote = fetchSaleByIdRemote ?? ((id) async => null);

  final AppDatabase _db;
  final InvoiceNumberGenerator _invoiceNumbers;
  final Future<SaleDetail?> Function({String? provisionalInvoiceNumber, String? canonicalInvoiceNumber})
  _lookupSaleRemote;
  final Future<SaleDetail?> Function(String id) _fetchSaleByIdRemote;

  @override
  Future<CompletedSale> completeSale({
    required String id,
    required String storeId,
    required List<CartLine> lines,
    String? customerId,
  }) {
    if (lines.isEmpty) {
      throw ArgumentError('A sale requires at least one line item.');
    }

    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.sales,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing != null && existing.status == 'completed') {
        return CompletedSale(
          id: existing.id,
          provisionalInvoiceNumber: existing.provisionalInvoiceNumber,
          grandTotalMinorUnits: existing.grandTotalMinorUnits,
          completedAt: existing.completedAt!,
        );
      }

      final grandTotalMinorUnits = lines.fold<int>(
        0,
        (sum, line) => sum + line.lineTotalMinorUnits,
      );
      final completedAt = DateTime.now();
      // Sprint 30: an existing draft/held row (the normal case — the cart
      // was auto-persisted from its first item onward) already carries the
      // one provisional invoice number assigned at its own creation; reused
      // here, never regenerated. Only the no-existing-row fallback (a direct
      // call bypassing the draft flow, e.g. a test) mints a fresh one.
      final provisionalInvoiceNumber =
          existing?.provisionalInvoiceNumber ?? await _invoiceNumbers.next();
      final createdAt = existing?.createdAt ?? completedAt;

      await _db
          .into(_db.sales)
          .insertOnConflictUpdate(
            SalesCompanion.insert(
              id: id,
              status: 'completed',
              provisionalInvoiceNumber: provisionalInvoiceNumber,
              subtotalMinorUnits: grandTotalMinorUnits,
              grandTotalMinorUnits: grandTotalMinorUnits,
              completedAt: Value(completedAt),
              createdAt: Value(createdAt),
              customerId: Value(customerId),
            ),
          );

      await (_db.delete(
        _db.saleLineItems,
      )..where((t) => t.saleId.equals(id))).go();

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

      await (_db.delete(
        _db.salePayments,
      )..where((t) => t.saleId.equals(id))).go();
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
        // Added Sprint 32 (backlog.md M3 item 2) — omitted entirely when
        // null, not sent as a literal `null`, matching the request schema's
        // own `.optional()` (not `.nullable()`) shape.
        'customer_id': ?customerId,
      });
      // Plain `.insert()`, not `insertOnConflictUpdate` — this point is only
      // ever reached once per genuinely new completion (the idempotent-
      // replay check above returns early for an already-`completed` id), so
      // a conflict here is a real bug elsewhere, not a case to silently
      // paper over. Also preserves the existing atomicity test's own
      // premise (a pre-seeded conflicting row must throw, not be updated).
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
        completedAt: completedAt,
      );
    });
  }

  @override
  Future<List<CompletedSale>> listCompletedSales() async {
    final rows =
        await (_db.select(_db.sales)
              ..where((t) => t.status.equals('completed'))
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.completedAt, mode: OrderingMode.desc),
              ]))
            .get();
    return rows
        .map(
          (row) => CompletedSale(
            id: row.id,
            provisionalInvoiceNumber: row.provisionalInvoiceNumber,
            grandTotalMinorUnits: row.grandTotalMinorUnits,
            completedAt: row.completedAt!,
          ),
        )
        .toList();
  }

  @override
  Future<SaleDetail?> getSaleDetail(String id) async {
    final sale = await (_db.select(
      _db.sales,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (sale == null) return null;

    final lineItemRows = await (_db.select(
      _db.saleLineItems,
    )..where((t) => t.saleId.equals(id))).get();

    final lines = <SaleLineDetail>[];
    for (final lineItem in lineItemRows) {
      final product = await (_db.select(
        _db.products,
      )..where((t) => t.id.equals(lineItem.productId))).getSingleOrNull();
      lines.add(
        SaleLineDetail(
          id: lineItem.id,
          productId: lineItem.productId,
          productName: product?.name,
          quantity: lineItem.quantity.round(),
          unitPriceMinorUnits: lineItem.unitPriceMinorUnits,
          lineTotalMinorUnits: lineItem.lineTotalMinorUnits,
        ),
      );
    }

    return SaleDetail(
      id: sale.id,
      provisionalInvoiceNumber: sale.provisionalInvoiceNumber,
      completedAt: sale.completedAt!,
      grandTotalMinorUnits: sale.grandTotalMinorUnits,
      lines: lines,
    );
  }

  @override
  Future<SaleDetail?> lookupSale({
    String? provisionalInvoiceNumber,
    String? canonicalInvoiceNumber,
  }) async {
    try {
      final remote = await _lookupSaleRemote(
        provisionalInvoiceNumber: provisionalInvoiceNumber,
        canonicalInvoiceNumber: canonicalInvoiceNumber,
      );
      if (remote != null) return _withLocalProductNames(remote);
    } catch (_) {
      // Deliberately swallowed — falls through to the local fallback below,
      // per the docstring on `SaleRepository.lookupSale`.
    }

    if (provisionalInvoiceNumber == null) return null;
    final sale = await (_db.select(_db.sales)..where(
          (t) =>
              t.provisionalInvoiceNumber.equals(provisionalInvoiceNumber) &
              t.status.equals('completed'),
        ))
        .getSingleOrNull();
    if (sale == null) return null;
    return getSaleDetail(sale.id);
  }

  @override
  Future<SaleDetail?> fetchRemoteSaleDetail(String id) async {
    final remote = await _fetchSaleByIdRemote(id);
    if (remote == null) return null;
    return _withLocalProductNames(remote);
  }

  /// The network-mapped [SaleDetail] has no product names (a catalogue
  /// concern the server's sale response never carries) — resolved here
  /// against the local product cache, the same join `getSaleDetail`'s own
  /// local path already does.
  Future<SaleDetail> _withLocalProductNames(SaleDetail detail) async {
    final resolvedLines = <SaleLineDetail>[];
    for (final line in detail.lines) {
      final product = await (_db.select(
        _db.products,
      )..where((t) => t.id.equals(line.productId))).getSingleOrNull();
      resolvedLines.add(
        SaleLineDetail(
          id: line.id,
          productId: line.productId,
          productName: product?.name,
          quantity: line.quantity,
          unitPriceMinorUnits: line.unitPriceMinorUnits,
          lineTotalMinorUnits: line.lineTotalMinorUnits,
        ),
      );
    }
    return SaleDetail(
      id: detail.id,
      provisionalInvoiceNumber: detail.provisionalInvoiceNumber,
      completedAt: detail.completedAt,
      grandTotalMinorUnits: detail.grandTotalMinorUnits,
      lines: resolvedLines,
    );
  }

  @override
  Future<void> saveDraft({
    required String id,
    required String storeId,
    required List<CartLine> lines,
    String? customerId,
  }) {
    if (lines.isEmpty) {
      throw ArgumentError(
        'An empty cart has nothing to persist — call deleteDraft instead.',
      );
    }

    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.sales,
      )..where((t) => t.id.equals(id))).getSingleOrNull();

      final grandTotalMinorUnits = lines.fold<int>(
        0,
        (sum, line) => sum + line.lineTotalMinorUnits,
      );
      final now = DateTime.now();
      // Sprint 30 (pos/specification.md §1's third design decision): the
      // provisional invoice number is assigned once, at the cart's own
      // creation (its first `saveDraft` call), and never reassigned —
      // whether or not this particular cart ever reaches completion.
      final provisionalInvoiceNumber =
          existing?.provisionalInvoiceNumber ?? await _invoiceNumbers.next();

      await _db
          .into(_db.sales)
          .insertOnConflictUpdate(
            SalesCompanion.insert(
              id: id,
              status: 'draft',
              provisionalInvoiceNumber: provisionalInvoiceNumber,
              subtotalMinorUnits: grandTotalMinorUnits,
              grandTotalMinorUnits: grandTotalMinorUnits,
              createdAt: Value(existing?.createdAt ?? now),
              customerId: Value(customerId),
            ),
          );

      await (_db.delete(
        _db.saleLineItems,
      )..where((t) => t.saleId.equals(id))).go();
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
      }
    });
  }

  @override
  Future<void> deleteDraft(String id) {
    return _db.transaction(() async {
      await (_db.delete(
        _db.saleLineItems,
      )..where((t) => t.saleId.equals(id))).go();
      await (_db.delete(_db.sales)..where((t) => t.id.equals(id))).go();
    });
  }

  @override
  Future<void> holdSale(String id) async {
    await (_db.update(_db.sales)..where(
          (t) => t.id.equals(id) & t.status.equals('draft'),
        ))
        .write(const SalesCompanion(status: Value('held')));
  }

  @override
  Future<ResumedCart?> resumeSale(String id) {
    return _db.transaction(() async {
      final updated =
          await (_db.update(_db.sales)..where(
                (t) => t.id.equals(id) & t.status.equals('held'),
              ))
              .writeReturning(const SalesCompanion(status: Value('draft')));
      if (updated.isEmpty) return null;
      final row = updated.first;

      final lineItemRows = await (_db.select(
        _db.saleLineItems,
      )..where((t) => t.saleId.equals(id))).get();

      final lines = <CartLine>[];
      for (final lineItem in lineItemRows) {
        final product = await (_db.select(
          _db.products,
        )..where((t) => t.id.equals(lineItem.productId))).getSingleOrNull();
        lines.add(
          CartLine(
            productId: lineItem.productId,
            productName: product?.name ?? 'Unknown product',
            unitPriceMinorUnits: lineItem.unitPriceMinorUnits,
            quantity: lineItem.quantity.round(),
          ),
        );
      }

      // Sprint 32 (backlog.md M3 item 2): the attached customer, if any,
      // survives hold/resume the same way line items already do (FR-026).
      // Looked up directly against the shared local database — the same
      // "query another table via the shared AppDatabase" shape this same
      // function already uses for `_db.products` above, not a cross-feature
      // file import (mobile-structure.md's layering rule concerns imports
      // between `data/` packages, not which tables one repository reads).
      String? customerName;
      String? customerPhone;
      if (row.customerId != null) {
        final customer = await (_db.select(
          _db.customers,
        )..where((t) => t.id.equals(row.customerId!))).getSingleOrNull();
        customerName = customer?.name;
        customerPhone = customer?.phone;
      }

      return ResumedCart(
        lines: lines,
        customerId: row.customerId,
        customerName: customerName,
        customerPhone: customerPhone,
      );
    });
  }

  @override
  Future<List<HeldSale>> listHeldSales() async {
    final rows =
        await (_db.select(_db.sales)
              ..where((t) => t.status.equals('held'))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final result = <HeldSale>[];
    for (final row in rows) {
      final itemCount =
          await (_db.selectOnly(_db.saleLineItems)
                ..addColumns([_db.saleLineItems.id.count()])
                ..where(_db.saleLineItems.saleId.equals(row.id)))
              .map((r) => r.read(_db.saleLineItems.id.count()) ?? 0)
              .getSingle();
      result.add(
        HeldSale(
          id: row.id,
          provisionalInvoiceNumber: row.provisionalInvoiceNumber,
          itemCount: itemCount,
          grandTotalMinorUnits: row.grandTotalMinorUnits,
          createdAt: row.createdAt,
        ),
      );
    }
    return result;
  }
}
