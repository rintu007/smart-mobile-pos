import 'package:drift/drift.dart';

/// M0-minimal slice of docs/07-database/schema-server.md's `sales` table —
/// the till screen's scope (backlog.md item 6) is cash-only, single-payment,
/// no discount/tax/hold-resume/customer link. Those belong to M2 ("Discount,
/// tax computation, split payment, hold/resume, Trading Day" — backlog.md
/// §2), and `device_id`/`trading_day_id`/`customer_id` reference local tables
/// that don't exist yet either — added when the sprint that needs them
/// builds them, not stubbed in advance.
class Sales extends Table {
  /// Client-generated UUID, doubling as the idempotency key
  /// (`client_operation_id` on the server) — ADR-0007.
  TextColumn get id => text()();

  /// 'draft' / 'held' / 'completed' / 'cancelled', matching the server's
  /// CHECK constraint — M0's till only ever writes 'completed', the others
  /// are real server states a future milestone's UI will produce.
  TextColumn get status => text()();

  /// ADR-0008 — generated locally, immutable after creation.
  TextColumn get provisionalInvoiceNumber => text()();

  /// `integer()`, not `int64()` — see products.dart's comment on
  /// `priceMinorUnits` for why (Android-only V1, no web-precision concern).
  IntColumn get subtotalMinorUnits => integer()();

  IntColumn get grandTotalMinorUnits => integer()();

  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
