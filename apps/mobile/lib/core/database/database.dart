import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/device_identity.dart';
import 'tables/local_provisional_sequence.dart';
import 'tables/outbound_queue.dart';
import 'tables/products.dart';
import 'tables/sale_line_items.dart';
import 'tables/sale_payments.dart';
import 'tables/sales.dart';
import 'tables/stock_movements.dart';
import 'tables/store_context.dart';

part 'database.g.dart';

/// M0's local database — outbound_queue plus the minimal products/sales/
/// stock_movements slice backlog.md item 4 scopes, plus `StoreContext`
/// (Sprint 08, a local cache of the device's own `store_id`) and
/// `DeviceIdentity`/`LocalProvisionalSequence` (Sprint 09, ADR-0008's local
/// invoice-numbering half). Every other local table in schema-local.md
/// (categories, units, customers, the server-authoritative caches, ...) is
/// added by the sprint that actually needs it, not stubbed here ahead of the
/// backlog.
@DriftDatabase(
  tables: [
    DeviceIdentity,
    LocalProvisionalSequence,
    OutboundQueue,
    Products,
    Sales,
    SaleLineItems,
    SalePayments,
    StockMovements,
    StoreContext,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'smart_pos_x');
  }
}
