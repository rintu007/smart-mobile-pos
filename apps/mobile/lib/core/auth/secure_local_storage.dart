import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The narrow slice of `FlutterSecureStorage`'s API this file actually needs — letting tests
/// substitute a real in-memory fake instead of mocking `flutter_secure_storage`'s own platform
/// channel, this codebase's established "fake, not a mock" testing convention (e.g. Sprint 39's
/// `_FakeEscPosReceiptEncoder`).
abstract class SecureKeyValueStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

/// Public since Sprint 48 — [getOrCreateDatabaseEncryptionKey] in `core/database/` is a second,
/// independent caller (a different key, same underlying platform secure storage), not just
/// [SecureLocalStorage]'s own internal default.
class FlutterSecureStorageAdapter implements SecureKeyValueStore {
  const FlutterSecureStorageAdapter(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

/// Sprint 47 (docs/12-security/data-protection.md §3a, docs/12-security/owasp-checklist.md M1) —
/// persists the Supabase session via the platform's own secure storage (Android Keystore-backed
/// EncryptedSharedPreferences, iOS Keychain), never `supabase_flutter`'s own default
/// `SharedPreferencesLocalStorage`, which is plaintext on Android — confirmed live: this app never
/// passed a custom `localStorage` to `Supabase.initialize`, so every session token this app has
/// ever persisted sat in an unencrypted preferences file. `flutter_secure_storage` was already a
/// `pubspec.yaml` dependency but had never actually been imported anywhere in this app — found
/// while verifying M1's claimed mitigation against the real code, not assumed from the dependency
/// list alone.
class SecureLocalStorage extends LocalStorage {
  // No explicit `AndroidOptions` — `flutter_secure_storage` (10.x) deprecated
  // `encryptedSharedPreferences` and auto-migrates to its own custom ciphers by default; passing it
  // is a no-op the package itself now warns against (found via `flutter analyze`, not assumed).
  SecureLocalStorage({SecureKeyValueStore? store})
    : _store = store ?? FlutterSecureStorageAdapter(const FlutterSecureStorage());

  final SecureKeyValueStore _store;

  // Distinct from supabase_flutter's own SharedPreferencesLocalStorage default key name — a fresh
  // key under a different storage backend entirely. No migration from the old plaintext value is
  // attempted: no real installed base exists yet to migrate, per release-checklist.md's own
  // "not pilot-ready today" status — a signed-in user simply signs in again once, the same
  // one-time cost every other pre-pilot schema/storage change in this project has already accepted.
  static const _sessionKey = 'supabase.session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    return await _store.read(key: _sessionKey) != null;
  }

  @override
  Future<String?> accessToken() => _store.read(key: _sessionKey);

  @override
  Future<void> removePersistedSession() => _store.delete(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(key: _sessionKey, value: persistSessionString);
}
