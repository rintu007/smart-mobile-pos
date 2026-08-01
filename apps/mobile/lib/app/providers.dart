import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database.dart';

/// Riverpod root providers — merged into `ProviderScope` by `main.dart`, per
/// mobile-structure.md §4. `AppDatabase` is the one primitive every feature's
/// data layer will eventually depend on; it's the only provider that exists
/// until a feature needs its own.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Proves the local database actually opens and is queryable — the mobile
/// equivalent of Sprint 02's "at least one real HTTP request" rule
/// (retrospective-log.md's Sprint 02 addendum): a schema that only compiles
/// is not the same claim as a schema that opens.
final productCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return (await db.select(db.products).get()).length;
});
