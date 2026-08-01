import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/outbound_queue.dart';
import 'tables/products.dart';
import 'tables/sale_line_items.dart';
import 'tables/sale_payments.dart';
import 'tables/sales.dart';
import 'tables/stock_movements.dart';

part 'database.g.dart';

/// M0's local database — outbound_queue plus the minimal products/sales/
/// stock_movements slice backlog.md item 4 scopes. Every other local table in
/// schema-local.md (categories, units, customers, shop_settings, the
/// server-authoritative caches, ...) is added by the sprint that actually
/// needs it, not stubbed here ahead of the backlog.
@DriftDatabase(
  tables: [
    OutboundQueue,
    Products,
    Sales,
    SaleLineItems,
    SalePayments,
    StockMovements,
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
