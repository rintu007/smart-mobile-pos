import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import 'bluetooth_printer_repository.dart';

/// Reads/writes the single-row `PairedPrinterCache` — a purely local,
/// per-device convenience remembering the last printer chosen from
/// `/settings/printer`. Never talks to the server; see that table's own
/// doc comment for why a paired printer is not `shop_settings`/`printer_config`
/// data. Added Sprint 39 (backlog.md M4 item 4).
class PairedPrinterRepository {
  PairedPrinterRepository(this._db);

  final AppDatabase _db;

  Future<PairedPrinter?> getPairedPrinter() async {
    final row = await (_db.select(
      _db.pairedPrinterCache,
    )..where((t) => t.id.equals('current'))).getSingleOrNull();
    if (row?.macAddress == null) return null;
    return PairedPrinter(name: row!.name ?? row.macAddress!, macAddress: row.macAddress!);
  }

  Future<void> setPairedPrinter(PairedPrinter printer) {
    return _db
        .into(_db.pairedPrinterCache)
        .insertOnConflictUpdate(
          PairedPrinterCacheCompanion(
            id: const Value('current'),
            macAddress: Value(printer.macAddress),
            name: Value(printer.name),
          ),
        );
  }
}
