import '../entities/shop_settings.dart';

/// Thrown when the server rejects a `PATCH` with `403 PERMISSION_DENIED` —
/// [DR-021](../../../../../../docs/03-functional-requirements/business-rules.md)'s
/// Owner-only rule. Read the HTTP status directly rather than the
/// server-error-code body: the same minimal, no-new-capability shape
/// `reports/specification.md` §1 already established for this codebase's
/// only other client-side role signal.
class SettingsPermissionDeniedException implements Exception {
  const SettingsPermissionDeniedException();
}

/// Thrown on `409 SETTINGS_CONFLICT` — `base_updated_at` no longer matches
/// the row's current `updated_at` (conflict-resolution.md §4's whole-row
/// reject, never a field merge). The caller is expected to re-fetch and
/// re-apply, not retry the same request.
class SettingsConflictException implements Exception {
  const SettingsConflictException();
}

/// `/settings` (M4 item 3) — no local Drift cache, unlike every other
/// repository in this codebase. `PATCH /settings` requires connectivity by
/// design (settings/specification.md §2/§7 — `SETTINGS_CHANGE_REQUIRES_CONNECTIVITY`
/// is not offline-queued), and `GET /settings` is read on a dedicated
/// screen, not on every app-open path the way `ShopSettingsCache`'s
/// Reports-only fields are — so there is no proportionate reason to extend
/// that cache (its own doc comment says as much) or add a new one here.
/// Both methods are plain live calls; a failure surfaces as a normal error
/// state, the same shape `return_approvals_screen.dart` already uses for a
/// role-gated screen with a real backing network call.
abstract class SettingsRepository {
  Future<ShopSettings> getSettings();

  Future<ShopSettings> updateSettings({
    required String clientOperationId,
    required DateTime baseUpdatedAt,
    required String taxMode,
    required int taxRateBasisPoints,
    required String pricingMode,
    required String roundingRule,
    required String currencyCode,
    required int lowStockThresholdQuantity,
    int? discountAutoApprovalThresholdMinorUnits,
    int? returnAutoApprovalThresholdMinorUnits,
  });
}
