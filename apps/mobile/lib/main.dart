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
import 'core/database/device_identity_repository.dart';
import 'core/database/legacy_database_reset.dart';
import 'core/network/api_client.dart';
import 'core/network/device_registration_api.dart';
import 'core/store_context/store_context_providers.dart';
import 'features/authentication/presentation/providers/auth_providers.dart';

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
  final db = AppDatabase.encrypted(databaseEncryptionKey);

  // Sprint 56 (docs/11-api/authentication.md §2/§4, docs/12-security/owasp-checklist.md A01) —
  // resolved once at startup, purely locally, regardless of sign-in state (this is a local
  // identity, not a network call): the value every subsequent request's `X-Device-Id` header
  // carries. If a session already exists (an app relaunch, not a fresh sign-in), also (re-)register
  // it now — best-effort, matching `autoSyncOnStartProvider`'s own swallowed-failure pattern below;
  // a transient failure here isn't fatal, since the very next authenticated call would surface
  // `DEVICE_REVOKED` anyway if registration genuinely never succeeds. A *fresh* interactive
  // sign-in registers separately, from `SignInController.signIn()` itself, since no session exists
  // yet at this point in that case.
  final deviceIdentity = await ensureDeviceIdentity(db);
  if (Supabase.instance.client.auth.currentSession != null) {
    try {
      final dio = buildApiClient(clientDeviceId: deviceIdentity.clientDeviceId);
      await registerDevice(dio, deviceIdentity.clientDeviceId);
    } catch (_) {
      // Deliberately swallowed — see docstring above.
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) {
          ref.onDispose(db.close);
          return db;
        }),
        apiClientProvider.overrideWith(
          (ref) => buildApiClient(
            clientDeviceId: deviceIdentity.clientDeviceId,
            onDeviceRevoked: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ),
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
