import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart' hide Unit;
import 'package:mobile/features/catalogue/data/repositories/drift_unit_repository.dart';
import 'package:mobile/features/catalogue/domain/entities/unit.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('createUnit calls the server first, then caches the result locally', () async {
    var serverCalled = false;
    final repository = DriftUnitRepository(
      db,
      ({required id, required name, required symbol, required allowsFractional}) async {
        serverCalled = true;
      },
      () async => [],
    );

    final unit = await repository.createUnit(
      id: 'unit-1',
      name: 'Kilogram',
      symbol: 'kg',
      allowsFractional: true,
    );

    expect(serverCalled, isTrue);
    expect(unit.symbol, 'kg');
    expect(unit.allowsFractional, isTrue);
    final row = await (db.select(db.units)..where((t) => t.id.equals('unit-1'))).getSingle();
    expect(row.symbol, 'kg');
    expect(row.allowsFractional, isTrue);
  });

  test('does not cache locally if the server call throws', () async {
    final repository = DriftUnitRepository(
      db,
      ({required id, required name, required symbol, required allowsFractional}) async =>
          throw Exception('offline'),
      () async => [],
    );

    await expectLater(
      () => repository.createUnit(
        id: 'unit-1',
        name: 'Kilogram',
        symbol: 'kg',
        allowsFractional: true,
      ),
      throwsA(anything),
    );

    final rows = await db.select(db.units).get();
    expect(rows, isEmpty);
  });

  test('listAll returns the local cache, name-ordered', () async {
    final repository = DriftUnitRepository(
      db,
      ({required id, required name, required symbol, required allowsFractional}) async {},
      () async => [],
    );
    await repository.createUnit(id: 'unit-2', name: 'Piece', symbol: 'pc', allowsFractional: false);
    await repository.createUnit(id: 'unit-1', name: 'Kilogram', symbol: 'kg', allowsFractional: true);

    final units = await repository.listAll();

    expect(units.map((u) => u.name).toList(), ['Kilogram', 'Piece']);
  });

  test('refreshFromServer caches every unit the server returns', () async {
    final repository = DriftUnitRepository(
      db,
      ({required id, required name, required symbol, required allowsFractional}) async {},
      () async => [
        const Unit(id: 'unit-1', name: 'Kilogram', symbol: 'kg', allowsFractional: true),
        const Unit(id: 'unit-2', name: 'Piece', symbol: 'pc', allowsFractional: false),
      ],
    );

    await repository.refreshFromServer();

    final units = await repository.listAll();
    expect(units, hasLength(2));
  });
}
