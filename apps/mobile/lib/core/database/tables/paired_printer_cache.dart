import 'package:drift/drift.dart';

/// Added Sprint 39 (backlog.md M4 item 4) — a one-row local cache, matching
/// `StoreContext`/`ShopSettingsCache`'s own established `'current'`-id
/// convention. Deliberately **not** synced through `shop_settings` /
/// `printer_config` at all: which Bluetooth printer is paired is a
/// per-device fact (each phone pairs with whatever printer is physically
/// nearest it), and `shop_settings` is one row per *tenant* — there is no
/// `devices` table anywhere in this schema for a per-device row to belong
/// to (the same gap Trading Day's own spec already named). Storing a MAC
/// address in a shop-wide row would mean every device overwrites every
/// other device's own pairing on the next sync — settings/specification.md
/// §1's Sprint 39 design decision.
class PairedPrinterCache extends Table {
  TextColumn get id => text()();

  TextColumn get macAddress => text().nullable()();

  TextColumn get name => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
