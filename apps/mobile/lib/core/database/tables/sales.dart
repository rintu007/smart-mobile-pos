import 'package:drift/drift.dart';

/// M0-minimal slice of docs/07-database/schema-server.md's `sales` table —
/// the till screen's original scope (backlog.md item 6) was cash-only,
/// single-payment, no discount/tax/customer link. Discount/tax/split-payment
/// (M2) landed server-side only (Sprints 27-29) and haven't reached this
/// local table yet, a real, separately-named gap — see this table's own
/// `docs/modules/pos/specification.md §1` note. Hold/Resume (Sprint 30) is
/// the one M2 item this local table does implement. `device_id`/
/// `trading_day_id`/`customer_id` reference local tables that don't exist
/// yet either — added when the sprint that needs them builds them, not
/// stubbed in advance.
class Sales extends Table {
  /// Client-generated UUID, doubling as the idempotency key
  /// (`client_operation_id` on the server) — ADR-0007.
  TextColumn get id => text()();

  /// 'draft' / 'held' / 'completed' / 'cancelled', matching the server's
  /// CHECK constraint. Sprint 30 (Hold/Resume) is the first code to write
  /// 'draft'/'held' — a row is created as 'draft' the moment the first cart
  /// line is added, kept in sync with the active cart on every mutation, and
  /// becomes immutable only once this column first reaches 'completed'
  /// (schema-local.md's own corrected classification).
  TextColumn get status => text()();

  /// ADR-0008 — generated locally, immutable after creation.
  TextColumn get provisionalInvoiceNumber => text()();

  /// `integer()`, not `int64()` — see products.dart's comment on
  /// `priceMinorUnits` for why (Android-only V1, no web-precision concern).
  IntColumn get subtotalMinorUnits => integer()();

  IntColumn get grandTotalMinorUnits => integer()();

  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Added Sprint 30 (backlog.md M2 item 6, Hold/Resume) — schema v3->v4. A
  /// real, pre-existing gap: every server Tier 1/2 table has `created_at` by
  /// convention (schema-server.md's own header note), but this table's
  /// M0-minimal slice omitted it since nothing locally needed "when was this
  /// row first written" until a draft/held row could exist to ask that
  /// question of. Nullable for migration safety against existing rows
  /// (backfilled from `completed_at` in the same migration step) — see
  /// database.dart's own migration comment. Used to order the Held Carts
  /// list, most-recently-held first.
  DateTimeColumn get createdAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
