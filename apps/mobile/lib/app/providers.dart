import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database.dart';

/// Riverpod root providers — merged into `ProviderScope` by `main.dart`, per
/// mobile-structure.md §4. `AppDatabase` is the one primitive every feature's
/// data layer will eventually depend on; it's the only provider that exists
/// until a feature needs its own.
///
/// Sprint 48 (docs/12-security/data-protection.md §3, OWASP M9) — has no default body of its own
/// any more: opening the real database now needs a SQLCipher key resolved asynchronously from
/// secure storage first (`getOrCreateDatabaseEncryptionKey`), which a synchronous `Provider`
/// can't do internally without either becoming a `FutureProvider` (rippling an async wait into
/// every one of this provider's ~11 existing synchronous consumers, disproportionate to this
/// change) or silently falling back to an unencrypted database. `main.dart` resolves the key
/// during startup and overrides this provider with the real, encrypted `AppDatabase`, same
/// pattern `storeContextProvider`/`autoSyncOnStartProvider` already use in tests. Failing loudly
/// here if that override is missing is deliberate — the same fail-fast style as
/// `Env.assertConfigured()` — rather than ever constructing an unencrypted database by accident.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError(
    'appDatabaseProvider has no default implementation and must be overridden: with a real, '
    'encrypted AppDatabase in main.dart (after resolving the SQLCipher key), or an in-memory '
    'AppDatabase(NativeDatabase.memory()) in tests.',
  );
});

/// Proves the local database actually opens and is queryable — the mobile
/// equivalent of Sprint 02's "at least one real HTTP request" rule
/// (retrospective-log.md's Sprint 02 addendum): a schema that only compiles
/// is not the same claim as a schema that opens.
final productCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return (await db.select(db.products).get()).length;
});
