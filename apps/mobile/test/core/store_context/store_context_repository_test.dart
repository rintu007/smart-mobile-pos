import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart';
import 'package:mobile/core/store_context/store_context_repository.dart';
import 'package:mobile/core/store_context/store_summary.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('getCachedStoreId returns null before anything has been fetched', () async {
    final repository = StoreContextRepository(db, () async => []);
    expect(await repository.getCachedStoreId(), isNull);
  });

  test('ensureStoreContext fetches and caches on first call, then reads the cache', () async {
    var fetchCount = 0;
    final repository = StoreContextRepository(db, () async {
      fetchCount++;
      return [const StoreSummary(id: 'store-1', name: 'Main Store')];
    });

    final first = await repository.ensureStoreContext();
    final second = await repository.ensureStoreContext();

    expect(first, 'store-1');
    expect(second, 'store-1');
    expect(fetchCount, 1, reason: 'the second call should read the cache, not fetch again');
    expect(await repository.getCachedStoreId(), 'store-1');
  });

  test('refreshFromServer overwrites a previously cached store', () async {
    final repository = StoreContextRepository(
      db,
      () async => [const StoreSummary(id: 'store-old', name: 'Old')],
    );
    await repository.ensureStoreContext();

    final repositoryWithNewStore = StoreContextRepository(
      db,
      () async => [const StoreSummary(id: 'store-new', name: 'New')],
    );
    final refreshed = await repositoryWithNewStore.refreshFromServer();

    expect(refreshed, 'store-new');
    expect(await repositoryWithNewStore.getCachedStoreId(), 'store-new');
  });

  test('refreshFromServer throws if the server returns no stores', () async {
    final repository = StoreContextRepository(db, () async => []);
    expect(() => repository.refreshFromServer(), throwsA(isA<StateError>()));
  });
}
