import 'package:drift/drift.dart';

// Same generated-row-class-name collision as `drift_category_repository.dart`
// (`Units` -> generated `Unit`), hidden for the same reason.
import '../../../../core/database/database.dart' hide Unit;
import '../../domain/entities/unit.dart';
import '../../domain/repositories/unit_repository.dart';

/// Concrete implementation, per mobile-structure.md §2 — same online-only,
/// cache-after-success shape as `DriftCategoryRepository`.
class DriftUnitRepository implements UnitRepository {
  DriftUnitRepository(this._db, this._createOnServer, this._fetchAll);

  final AppDatabase _db;
  final Future<void> Function({
    required String id,
    required String name,
    required String symbol,
    required bool allowsFractional,
  })
  _createOnServer;
  final Future<List<Unit>> Function() _fetchAll;

  @override
  Future<Unit> createUnit({
    required String id,
    required String name,
    required String symbol,
    required bool allowsFractional,
  }) async {
    await _createOnServer(id: id, name: name, symbol: symbol, allowsFractional: allowsFractional);
    await _db
        .into(_db.units)
        .insertOnConflictUpdate(
          UnitsCompanion.insert(
            id: id,
            name: name,
            symbol: symbol,
            allowsFractional: Value(allowsFractional),
          ),
        );
    return Unit(id: id, name: name, symbol: symbol, allowsFractional: allowsFractional);
  }

  @override
  Future<List<Unit>> listAll() async {
    final rows =
        await (_db.select(_db.units)..orderBy([
          (t) => OrderingTerm(expression: t.name),
        ])).get();
    return rows
        .map(
          (row) => Unit(
            id: row.id,
            name: row.name,
            symbol: row.symbol,
            allowsFractional: row.allowsFractional,
          ),
        )
        .toList();
  }

  @override
  Future<void> refreshFromServer() async {
    final units = await _fetchAll();
    for (final unit in units) {
      await _db
          .into(_db.units)
          .insertOnConflictUpdate(
            UnitsCompanion.insert(
              id: unit.id,
              name: unit.name,
              symbol: unit.symbol,
              allowsFractional: Value(unit.allowsFractional),
            ),
          );
    }
  }
}
