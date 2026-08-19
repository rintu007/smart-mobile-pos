import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

const _databaseFileName = 'smart_pos_x.sqlite';

/// Sprint 48 (docs/12-security/data-protection.md §3, OWASP M9) — this is the first sprint this
/// app has ever set a SQLCipher key, so any database file already sitting at this path predates
/// encryption and is guaranteed plaintext. Rather than issue `PRAGMA key` against a plaintext
/// file (undefined, corruption-risking behaviour — SQLCipher's key handling assumes the file is
/// either already one of its own encrypted files or genuinely new) or build bespoke
/// SQLCipher plaintext-export migration machinery (real, separate scope, disproportionate to
/// this pre-pilot, no-real-installed-base product per release-checklist.md), a legacy plaintext
/// file is deleted once so drift recreates a fresh encrypted one at the same path — the same
/// "no migration path, pre-pilot, accepted one-time reset" call already made for session-token
/// storage (Sprint 47) and the `erased_at` column (Sprint 46), applied here to the one case where
/// it risks real local test/demo data rather than a trivial re-sign-in.
Future<void> resetLegacyUnencryptedDatabaseIfPresent() async {
  final dir = await getApplicationDocumentsDirectory();
  await resetLegacyUnencryptedDatabaseAt(File(p.join(dir.path, _databaseFileName)));
}

/// The testable half of [resetLegacyUnencryptedDatabaseIfPresent] — takes the target file
/// directly instead of resolving it via `path_provider`'s platform channel, so tests can exercise
/// the actual plaintext-detection logic against a real temporary file with no platform mocking.
Future<void> resetLegacyUnencryptedDatabaseAt(File file) async {
  if (!file.existsSync()) return;

  final db = sqlite3.open(file.path);
  bool isLegacyPlaintext;
  try {
    // No PRAGMA key is set here. A SQLCipher-enabled sqlite3 build opens and reads a genuinely
    // plaintext file exactly like a plain sqlite3 build would (encryption is opt-in per
    // connection) — this only throws for a file that is already cipher-protected, which cannot
    // happen yet, since this sprint is the first time this app has ever written one.
    db.select('SELECT * FROM sqlite_master LIMIT 1');
    isLegacyPlaintext = true;
  } on SqliteException {
    isLegacyPlaintext = false;
  } finally {
    db.close();
  }

  if (isLegacyPlaintext) {
    file.deleteSync();
  }
}
