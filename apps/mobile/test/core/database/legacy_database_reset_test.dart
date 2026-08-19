import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/legacy_database_reset.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('legacy_database_reset_test');
    dbFile = File('${tempDir.path}/smart_pos_x.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('does nothing when no file exists at the path', () async {
    await resetLegacyUnencryptedDatabaseAt(dbFile);

    expect(dbFile.existsSync(), isFalse);
  });

  test('deletes a legacy plaintext database file', () async {
    final db = sqlite3.open(dbFile.path);
    db.execute('CREATE TABLE t (id INTEGER)');
    db.close();
    expect(dbFile.existsSync(), isTrue);

    await resetLegacyUnencryptedDatabaseAt(dbFile);

    expect(dbFile.existsSync(), isFalse);
  });

  test('leaves an already-encrypted database file untouched', () async {
    final db = sqlite3.open(dbFile.path);
    db.execute("PRAGMA key = \"x'${'ab' * 32}'\"");
    db.execute('CREATE TABLE t (id INTEGER)');
    db.close();
    expect(dbFile.existsSync(), isTrue);

    await resetLegacyUnencryptedDatabaseAt(dbFile);

    expect(dbFile.existsSync(), isTrue);
  });
}
