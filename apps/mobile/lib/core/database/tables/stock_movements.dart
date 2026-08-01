import 'package:drift/drift.dart';

/// Server values exactly, per schema-server.md's `movement_type` CHECK
/// constraint — the converter below must keep these in sync with that CHECK,
/// not with Dart's own enum-naming conventions (`return` is a reserved word,
/// hence `returnMovement`).
enum MovementType { opening, sale, returnMovement, adjustment }

class MovementTypeConverter extends TypeConverter<MovementType, String> {
  const MovementTypeConverter();

  static const _wireValues = {
    MovementType.opening: 'opening',
    MovementType.sale: 'sale',
    MovementType.returnMovement: 'return',
    MovementType.adjustment: 'adjustment',
  };

  @override
  MovementType fromSql(String fromDb) =>
      _wireValues.entries.firstWhere((e) => e.value == fromDb).key;

  @override
  String toSql(MovementType value) => _wireValues[value]!;
}

/// M0-minimal slice of docs/07-database/schema-server.md's `stock_movements`
/// table. Local cache is scoped to this store only (trivial in V1 — one store
/// per tenant), per schema-local.md. Omits `variant_id`/`batch_id`/
/// `serial_number` (V2+/V4 stubs with no V1 write path) and `device_id`
/// (the `devices` table doesn't exist locally yet — added once a sprint
/// actually needs device attribution, not guessed at here).
class StockMovements extends Table {
  /// Doubles as this row's own id, per ADR-0007 — same convention as the
  /// server's `client_operation_id`.
  TextColumn get id => text()();

  TextColumn get productId => text()();

  /// NUMERIC(14,3) on the server; stored as `real` here as a stated
  /// simplification — this project has an ADR (ADR-0006) establishing
  /// integer minor units specifically for money's floating-point risk, but no
  /// equivalent decision yet for fractional quantities. Revisit if/when
  /// `core/money`'s sibling quantity value type is designed, not silently
  /// carried forward as if it were already resolved.
  RealColumn get quantityDelta => real()();

  TextColumn get movementType => text().map(const MovementTypeConverter())();

  TextColumn get referenceType => text().nullable()();

  TextColumn get referenceId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}
