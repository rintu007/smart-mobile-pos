import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/auth/secure_local_storage.dart';
import 'package:mobile/core/database/database_encryption_key.dart';

class _FakeSecureKeyValueStore implements SecureKeyValueStore {
  final _values = <String, String>{};

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
  test('generates a 256-bit key (64 lowercase hex chars) on first call', () async {
    final key = await getOrCreateDatabaseEncryptionKey(_FakeSecureKeyValueStore());

    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);
  });

  test('returns the same key on a second call — idempotent, not regenerated', () async {
    final store = _FakeSecureKeyValueStore();

    final first = await getOrCreateDatabaseEncryptionKey(store);
    final second = await getOrCreateDatabaseEncryptionKey(store);

    expect(second, first);
  });

  test('two independent stores get two different keys — real randomness, not a fixed value', () async {
    final a = await getOrCreateDatabaseEncryptionKey(_FakeSecureKeyValueStore());
    final b = await getOrCreateDatabaseEncryptionKey(_FakeSecureKeyValueStore());

    expect(a, isNot(b));
  });

  test('is stored under its own key, distinct from the session-token key', () async {
    final store = _FakeSecureKeyValueStore();

    await getOrCreateDatabaseEncryptionKey(store);

    expect(await store.read(key: 'database.encryption_key'), isNotNull);
  });
}
