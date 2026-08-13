import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/categories.dart';
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
/// invoice-numbering half), and `Categories`/`Units` (Sprint 20, M1's own
/// backlog item 4 — local read caches, see their own table docstrings for
/// why they aren't queued via `outbound_queue` like `Products` is). Every
/// other local table in schema-local.md (customers, the server-authoritative
/// caches, ...) is added by the sprint that actually needs it, not stubbed
/// here ahead of the backlog.
@DriftDatabase(
  tables: [
    Categories,
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
  int get schemaVersion => 2;

  // The first-ever schema change in this project (Sprint 01 through Sprint
  // 19 all shipped as schemaVersion 1) — a real founder device already has
  // real local data from Sprint 16's own end-to-end proof, so this must be a
  // genuine, non-destructive migration, not a reinstall-and-recreate.
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
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'smart_pos_x');
  }
}
