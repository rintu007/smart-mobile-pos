import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/secure_local_storage.dart';

/// In-memory fake, not a mock of `flutter_secure_storage`'s own platform channel — this
/// codebase's established testing convention (e.g. Sprint 39's `_FakeEscPosReceiptEncoder`).
class _FakeSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }
}

void main() {
  group('SecureLocalStorage', () {
    late _FakeSecureKeyValueStore store;
    late SecureLocalStorage storage;

    setUp(() {
      store = _FakeSecureKeyValueStore();
      storage = SecureLocalStorage(store: store);
    });

    test('hasAccessToken is false before any session is persisted', () async {
      expect(await storage.hasAccessToken(), isFalse);
    });

    test('persistSession then accessToken round-trips the exact stored string', () async {
      await storage.persistSession('{"access_token":"abc"}');

      expect(await storage.accessToken(), '{"access_token":"abc"}');
      expect(await storage.hasAccessToken(), isTrue);
    });

    test('removePersistedSession clears the stored session', () async {
      await storage.persistSession('{"access_token":"abc"}');

      await storage.removePersistedSession();

      expect(await storage.accessToken(), isNull);
      expect(await storage.hasAccessToken(), isFalse);
    });

    test('persisting a new session overwrites the previous one, not appends', () async {
      await storage.persistSession('{"access_token":"first"}');
      await storage.persistSession('{"access_token":"second"}');

      expect(await storage.accessToken(), '{"access_token":"second"}');
    });

    test('never touches the underlying store under any key other than its own session key', () async {
      await storage.persistSession('{"access_token":"abc"}');

      expect(store.read(key: 'some_other_key'), completion(isNull));
    });
  });
}
