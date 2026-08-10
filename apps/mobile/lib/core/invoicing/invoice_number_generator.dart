import 'dart:math';

import 'package:drift/drift.dart';

import '../database/database.dart';

/// ADR-0008's local half: `{device_short_id}-{financial_year}-{sequence}`,
/// generated entirely locally from a per-device counter — no canonical
/// number, no server round-trip. Deliberately narrower than the full ADR:
/// `device_short_id` here is a local-only identity (`DeviceIdentity`), not
/// backed by a registered `devices` row yet (Authentication's
/// device-registration slice isn't built) — see sprint-09.md's own
/// dated note.
///
/// Callers run this from inside their own `AppDatabase.transaction` block
/// (same convention as `DriftProductRepository`) — Drift routes queries made
/// on `_db` from within an ambient transaction to that transaction
/// automatically, so this class never opens one of its own.
class InvoiceNumberGenerator {
  InvoiceNumberGenerator(this._db);

  final AppDatabase _db;

  static const _deviceRowId = 'current';
  static const _shortIdAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _shortIdLength = 6;

  Future<String> next({DateTime? now}) async {
    final deviceShortId = await _ensureDeviceShortId();
    final financialYear = _financialYearFor(now ?? DateTime.now());
    final sequence = await _nextSequence(financialYear);
    return '$deviceShortId-$financialYear-${sequence.toString().padLeft(6, '0')}';
  }

  Future<String> _ensureDeviceShortId() async {
    final existing = await (_db.select(
      _db.deviceIdentity,
    )..where((t) => t.id.equals(_deviceRowId))).getSingleOrNull();
    if (existing != null) return existing.shortId;

    final generated = _generateShortId();
    await _db
        .into(_db.deviceIdentity)
        .insert(
          DeviceIdentityCompanion.insert(
            id: _deviceRowId,
            shortId: generated,
          ),
        );
    return generated;
  }

  String _generateShortId() {
    final random = Random.secure();
    return List.generate(
      _shortIdLength,
      (_) => _shortIdAlphabet[random.nextInt(_shortIdAlphabet.length)],
    ).join();
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
