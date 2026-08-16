import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/categories.dart';
import 'tables/customers.dart';
import 'tables/device_identity.dart';
import 'tables/local_provisional_sequence.dart';
import 'tables/outbound_queue.dart';
import 'tables/products.dart';
import 'tables/sale_line_items.dart';
import 'tables/sale_payments.dart';
import 'tables/sales.dart';
import 'tables/stock_movements.dart';
import 'tables/store_context.dart';
import 'tables/units.dart';

part 'database.g.dart';

/// M0's local database — outbound_queue plus the minimal products/sales/
/// stock_movements slice backlog.md item 4 scopes, plus `StoreContext`
/// (Sprint 08, a local cache of the device's own `store_id`),
/// `DeviceIdentity`/`LocalProvisionalSequence` (Sprint 09, ADR-0008's local
/// invoice-numbering half), `Categories`/`Units` (Sprint 20, M1's own
/// backlog item 4 — local read caches, see their own table docstrings for
/// why they aren't queued via `outbound_queue` like `Products` is), and
/// `Customers` (Sprint 32, M3 item 2 — unlike Categories/Units, genuinely
/// offline-writable via `outbound_queue`, see customers.dart's own
/// docstring). Every other local table in schema-local.md (the
/// server-authoritative caches, ...) is added by the sprint that actually
/// needs it, not stubbed here ahead of the backlog.
@DriftDatabase(
  tables: [
    Categories,
    Customers,
    DeviceIdentity,
    LocalProvisionalSequence,
    OutboundQueue,
    Products,
    Sales,
    SaleLineItems,
    SalePayments,
    StockMovements,
    StoreContext,
    Units,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

  // The first schema change was Sprint 20 (schemaVersion 1 -> 2); Sprint 21
  // (backlog.md item 5) adds `sku`/`barcode` to `products` for the till's
  // offline barcode-scan lookup; Sprint 30 (M2 item 6, Hold/Resume) adds
  // `sales.created_at` — see sales.dart's own comment for why; Sprint 32 (M3
  // item 2) adds the `Customers` table and `sales.customer_id`. Same
  // non-destructive-migration discipline — a real founder device already
  // has real local data. Existing `'completed'` rows get `created_at`
  // backfilled from `completed_at` (a reasonable historical approximation,
  // not a precision claim) rather than left null.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(categories);
        await m.createTable(units);
        await m.addColumn(products, products.categoryId);
        await m.addColumn(products, products.unitId);
      }
      if (from < 3) {
        await m.addColumn(products, products.sku);
        await m.addColumn(products, products.barcode);
      }
      if (from < 4) {
        await m.addColumn(sales, sales.createdAt);
        await customStatement(
          'UPDATE sales SET created_at = completed_at WHERE created_at IS NULL AND completed_at IS NOT NULL',
        );
      }
      if (from < 5) {
        await m.createTable(customers);
        await m.addColumn(sales, sales.customerId);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'smart_pos_x');
  }
}
