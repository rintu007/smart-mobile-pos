import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart';

// Sprint 50's "app killed mid-sync" close-out named "Schema version mismatch after an update"
// (docs/13-offline-sync/test-plan.md §3) as the one remaining mobile-only failure scenario with
// zero test coverage. `database.dart`'s `MigrationStrategy.onUpgrade` has real, previously-untested
// data-preserving logic (the `sales.created_at` backfill added Sprint 30) — this proves it, rather
// than only proving "the schema opens" the way the rest of `database_test.dart` already does.
//
// There is no historical schema snapshot to migrate *from* (this project never captured one via
// `drift_dev schema generate`), so a genuine v3 database is reconstructed by doing the exact
// inverse of `onUpgrade`'s own `from < 4` through `from < 9` blocks against a fresh, real,
// current-shape database, then telling SQLite that file is at schema version 3 (drift's own
// migration bootstrapping compares SQLite's `user_version` pragma against `schemaVersion`, see
// drift_flutter/native.dart's own doc comment) before reopening it for real.
void main() {
  test(
    'upgrading from schema v3 backfills sales.created_at from completed_at (Sprint 30 migration)',
    () async {
      final tempDir = Directory.systemTemp.createTempSync('migration_test');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final dbFile = File('${tempDir.path}/migration_test.sqlite');

      final fresh = AppDatabase(NativeDatabase(dbFile));
      await fresh.into(fresh.sales).insert(
        SalesCompanion.insert(
          id: 'sale-1',
          status: 'completed',
          provisionalInvoiceNumber: 'PROV-0001',
          subtotalMinorUnits: 1000,
          grandTotalMinorUnits: 1000,
          completedAt: Value(DateTime.utc(2026, 8, 1, 10, 30)),
        ),
      );
      await fresh.close();

      // The mirror image of onUpgrade's from<4 through from<9 blocks — undoing exactly what each
      // one adds, in reverse order, so what's left matches a genuine v3 database.
      final raw = sqlite3.open(dbFile.path);
      raw.execute('DROP TABLE paired_printer_cache');
      raw.execute('DROP TABLE shop_settings_cache');
      raw.execute('DROP TABLE sync_cursors');
      raw.execute('DROP TABLE return_line_items');
      raw.execute('DROP TABLE returns');
      raw.execute('ALTER TABLE sales DROP COLUMN customer_id');
      raw.execute('DROP TABLE customers');
      raw.execute('ALTER TABLE sales DROP COLUMN created_at');
      raw.execute('PRAGMA user_version = 3');
      raw.close();

      final upgraded = AppDatabase(NativeDatabase(dbFile));
      addTearDown(() => upgraded.close());

      final row = await (upgraded.select(
        upgraded.sales,
      )..where((t) => t.id.equals('sale-1'))).getSingle();

      // Compared as instants, not by representation — Drift round-trips DateTimeColumn as local
      // time by default, so a literal UTC DateTime would mismatch on wall-clock fields alone
      // despite being the same moment.
      expect(row.createdAt, isNotNull);
      expect(row.createdAt!.isAtSameMomentAs(DateTime.utc(2026, 8, 1, 10, 30)), isTrue);
    },
  );

  test(
    'upgrading from schema v8 (where shop_settings_cache genuinely lacks footer_message) still '
    'adds it — the guard above must not skip a real, needed column add',
    () async {
      final tempDir = Directory.systemTemp.createTempSync('migration_test_v8');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final dbFile = File('${tempDir.path}/migration_test_v8.sqlite');

      final fresh = AppDatabase(NativeDatabase(dbFile));
      await fresh.customSelect('select 1').getSingle(); // forces schema creation before closing
      await fresh.close();

      // Undo only what from<9 adds — paired_printer_cache, and shop_settings_cache's
      // footer_message column — leaving a genuine v8 shape, unlike the v3 test above.
      final raw = sqlite3.open(dbFile.path);
      raw.execute('DROP TABLE paired_printer_cache');
      raw.execute('ALTER TABLE shop_settings_cache DROP COLUMN footer_message');
      raw.execute("INSERT INTO shop_settings_cache (id) VALUES ('current')");
      raw.execute('PRAGMA user_version = 8');
      raw.close();

      final upgraded = AppDatabase(NativeDatabase(dbFile));
      addTearDown(() => upgraded.close());

      final row = await (upgraded.select(
        upgraded.shopSettingsCache,
      )..where((t) => t.id.equals('current'))).getSingle();

      expect(row.footerMessage, isNull); // column exists now; no value was ever set for it
      final tableExists = await upgraded
          .customSelect(
            "SELECT COUNT(*) AS c FROM sqlite_master WHERE type = 'table' AND name = 'paired_printer_cache'",
          )
          .getSingle();
      expect(tableExists.read<int>('c'), 1);
    },
  );
}
