import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/auth/secure_local_storage.dart';
import 'core/config/env.dart';
import 'core/database/database.dart';
import 'core/database/database_encryption_key.dart';
import 'core/database/legacy_database_reset.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fails fast on a missing --dart-define rather than starting with a blank
  // or broken Supabase client — see ADR-0010.
  Env.assertConfigured();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
    // Sprint 47 (docs/12-security/owasp-checklist.md M1) — without this, supabase_flutter falls
    // back to its own SharedPreferencesLocalStorage default, plaintext on Android.
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureLocalStorage(),
    ),
  );

  // Sprint 48 (docs/12-security/data-protection.md §3, OWASP M9) — the local database is
  // SQLCipher-encrypted from this sprint onward. Reset any pre-encryption plaintext file left by
  // an earlier build before opening the real, keyed connection (see legacy_database_reset.dart's
  // own docstring for why a reset rather than a migration), then resolve the encryption key.
  await resetLegacyUnencryptedDatabaseIfPresent();
  final databaseEncryptionKey = await getOrCreateDatabaseEncryptionKey(
    FlutterSecureStorageAdapter(const FlutterSecureStorage()),
  );

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          final db = AppDatabase.encrypted(databaseEncryptionKey);
          ref.onDispose(db.close);
          return db;
        }),
      ],
      child: const SmartPosXApp(),
    ),
  );
}

class SmartPosXApp extends ConsumerWidget {
  const SmartPosXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'SmartPOS X',
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      routerConfig: router,
    );
  }
}
