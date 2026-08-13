import 'package:drift/drift.dart';

// `database.dart`'s Drift-generated row class for the `Categories` table is
// also named `Category`, colliding with this feature's own domain entity of
// the same name — same collision, same fix, as `drift_product_repository.dart`.
import '../../../../core/database/database.dart' hide Category;
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';

/// Concrete implementation, per mobile-structure.md §2. Unlike
/// `DriftProductRepository`, this one *does* call the network directly
/// (`_createOnServer`/`_fetchAll`, both injected — same testability
/// reasoning `StoreContextRepository` already established) — see
/// `CategoryRepository.createCategory`'s docstring for why: no
/// `category.create` sync-push operation type exists.
class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._db, this._createOnServer, this._fetchAll);

  final AppDatabase _db;
  final Future<void> Function({required String id, required String name}) _createOnServer;
  final Future<List<Category>> Function() _fetchAll;

  @override
  Future<Category> createCategory({required String id, required String name}) async {
    await _createOnServer(id: id, name: name);
    await _db
        .into(_db.categories)
        .insertOnConflictUpdate(CategoriesCompanion.insert(id: id, name: name));
    return Category(id: id, name: name);
  }

  @override
  Future<List<Category>> listAll() async {
    final rows =
        await (_db.select(_db.categories)..orderBy([
          (t) => OrderingTerm(expression: t.name),
        ])).get();
    return rows.map((row) => Category(id: row.id, name: row.name)).toList();
  }

  @override
  Future<void> refreshFromServer() async {
    final categories = await _fetchAll();
    for (final category in categories) {
      await _db
          .into(_db.categories)
          .insertOnConflictUpdate(
            CategoriesCompanion.insert(id: category.id, name: category.name),
          );
    }
  }
}
