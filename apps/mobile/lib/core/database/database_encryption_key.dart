import 'dart:math';

import '../auth/secure_local_storage.dart';

const _storageKey = 'database.encryption_key';

/// Sprint 48 (docs/12-security/data-protection.md §3, OWASP M9) — the SQLCipher key for the
/// local database. A fresh 256-bit random value generated on first launch, not derived from any
/// static app secret (which would make every installation's database decryptable by the same
/// key), persisted via the platform's own secure storage — a distinct key/value pair from
/// [SecureLocalStorage]'s session token, same underlying storage mechanism.
///
/// Hex-encoded and passed to SQLCipher in its raw-key form (`x'...'`, see `database.dart`) rather
/// than as a passphrase: passphrases go through PBKDF2 to derive a key from low-entropy human
/// input, which adds real cost for no benefit when the input is already 256 bits of randomness.
Future<String> getOrCreateDatabaseEncryptionKey(SecureKeyValueStore store) async {
  final existing = await store.read(key: _storageKey);
  if (existing != null) return existing;

  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final hexKey = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await store.write(key: _storageKey, value: hexKey);
  return hexKey;
}
