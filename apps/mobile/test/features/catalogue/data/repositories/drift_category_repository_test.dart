import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart' hide Category;
import 'package:mobile/features/catalogue/data/repositories/drift_category_repository.dart';
import 'package:mobile/features/catalogue/domain/entities/category.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('createCategory calls the server first, then caches the result locally', () async {
    var serverCalled = false;
    final repository = DriftCategoryRepository(
      db,
      ({required id, required name}) async {
        serverCalled = true;
      },
      () async => [],
    );

    final category = await repository.createCategory(id: 'cat-1', name: 'Dairy');

    expect(serverCalled, isTrue);
    expect(category.name, 'Dairy');
    final row = await (db.select(
      db.categories,
    )..where((t) => t.id.equals('cat-1'))).getSingle();
    expect(row.name, 'Dairy');
  });

  test('does not cache locally if the server call throws', () async {
    final repository = DriftCategoryRepository(
      db,
      ({required id, required name}) async => throw Exception('offline'),
      () async => [],
    );

    await expectLater(
      () => repository.createCategory(id: 'cat-1', name: 'Dairy'),
      throwsA(anything),
    );

    final rows = await db.select(db.categories).get();
    expect(rows, isEmpty);
  });

  test('listAll returns the local cache, name-ordered', () async {
    final repository = DriftCategoryRepository(db, ({required id, required name}) async {}, () async => []);
    await repository.createCategory(id: 'cat-2', name: 'Snacks');
    await repository.createCategory(id: 'cat-1', name: 'Dairy');

    final categories = await repository.listAll();

    expect(categories.map((c) => c.name).toList(), ['Dairy', 'Snacks']);
  });

  test('refreshFromServer caches every category the server returns', () async {
    final repository = DriftCategoryRepository(
      db,
      ({required id, required name}) async {},
      () async => [
        const Category(id: 'cat-1', name: 'Dairy'),
        const Category(id: 'cat-2', name: 'Snacks'),
      ],
    );

    await repository.refreshFromServer();

    final categories = await repository.listAll();
    expect(categories, hasLength(2));
  });
}
