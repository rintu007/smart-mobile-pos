import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'core/auth/secure_local_storage.dart';
import 'core/config/env.dart';

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
  runApp(const ProviderScope(child: SmartPosXApp()));
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
