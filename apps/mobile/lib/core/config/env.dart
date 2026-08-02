/// Build-time configuration, injected via `--dart-define` — never hardcoded.
///
/// See ADR-0010 (docs/adr/ADR-0010-mobile-config-via-dart-define.md) for why:
/// this is the only file in the app permitted to call `String.fromEnvironment`
/// for Supabase config.
class Env {
  const Env._();

  static const String _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  /// Throws immediately if config was not supplied at build/run time, per
  /// ADR-0010's "fail loudly at startup, not silently" requirement. Called
  /// once from `main()` before anything else touches Supabase.
  static void assertConfigured() {
    if (_supabaseUrl.isEmpty) {
      throw StateError(
        'SUPABASE_URL was not supplied. Run with '
        '--dart-define=SUPABASE_URL=<url> (or --dart-define-from-file).',
      );
    }
    if (_supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_ANON_KEY was not supplied. Run with '
        '--dart-define=SUPABASE_ANON_KEY=<key> (or --dart-define-from-file).',
      );
    }
  }

  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseAnonKey => _supabaseAnonKey;
}
