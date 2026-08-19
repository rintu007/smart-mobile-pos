import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/device_identity_repository.dart';

/// ADR-0008's local half: `{device_short_id}-{financial_year}-{sequence}`,
/// generated entirely locally from a per-device counter — no canonical
/// number, no server round-trip. `device_short_id` comes from the same
/// `DeviceIdentity` row the real, server-registered `client_device_id` now
/// also lives on (`ensureDeviceIdentity`, Sprint 56) — a local-only identity
/// on its own until Authentication's device-registration slice landed
/// (Sprint 55), see sprint-09.md's own dated note for the original gap.
///
/// Callers run this from inside their own `AppDatabase.transaction` block
/// (same convention as `DriftProductRepository`) — Drift routes queries made
/// on `_db` from within an ambient transaction to that transaction
/// automatically, so this class never opens one of its own.
class InvoiceNumberGenerator {
  InvoiceNumberGenerator(this._db);

  final AppDatabase _db;

  Future<String> next({DateTime? now}) async {
    final deviceIdentity = await ensureDeviceIdentity(_db);
    final financialYear = _financialYearFor(now ?? DateTime.now());
    final sequence = await _nextSequence(financialYear);
    return '${deviceIdentity.shortId}-$financialYear-${sequence.toString().padLeft(6, '0')}';
  }

  /// India's financial year rolls over April 1 — identifiers.md §3.
  /// Represented by its starting calendar year (e.g. FY2026-27 -> "2026"),
  /// matching sales.md's own worked example (`DEV042-2026-000118`).
  String _financialYearFor(DateTime date) {
    final startYear = date.month >= 4 ? date.year : date.year - 1;
    return startYear.toString();
  }

  Future<int> _nextSequence(String financialYear) async {
    final existing = await (_db.select(
      _db.localProvisionalSequence,
    )..where((t) => t.financialYear.equals(financialYear))).getSingleOrNull();
    final sequence = existing?.nextSequence ?? 1;

    await _db
        .into(_db.localProvisionalSequence)
        .insertOnConflictUpdate(
          LocalProvisionalSequenceCompanion.insert(
            financialYear: financialYear,
            nextSequence: Value(sequence + 1),
          ),
        );
    return sequence;
  }
}
