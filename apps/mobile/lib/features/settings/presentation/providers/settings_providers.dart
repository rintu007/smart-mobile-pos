import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/store_context/store_context_providers.dart';
import '../../data/data_sources/settings_api.dart' as api;
import '../../data/repositories/api_settings_repository.dart';
import '../../domain/entities/shop_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Manual (non-code-generated) Riverpod syntax, matching `unit_providers.dart`.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final dio = ref.watch(apiClientProvider);
  return ApiSettingsRepository(
    () => api.fetchSettings(dio),
    ({
      required clientOperationId,
      required baseUpdatedAt,
      taxMode,
      taxRateBasisPoints,
      pricingMode,
      roundingRule,
      currencyCode,
      lowStockThresholdQuantity,
      discountAutoApprovalThresholdMinorUnits,
      returnAutoApprovalThresholdMinorUnits,
      footerMessage,
    }) => api.updateSettingsOnServer(
      dio,
      clientOperationId: clientOperationId,
      baseUpdatedAt: baseUpdatedAt,
      taxMode: taxMode,
      taxRateBasisPoints: taxRateBasisPoints,
      pricingMode: pricingMode,
      roundingRule: roundingRule,
      currencyCode: currencyCode,
      lowStockThresholdQuantity: lowStockThresholdQuantity,
      discountAutoApprovalThresholdMinorUnits: discountAutoApprovalThresholdMinorUnits,
      returnAutoApprovalThresholdMinorUnits: returnAutoApprovalThresholdMinorUnits,
      footerMessage: footerMessage,
    ),
  );
});

/// No cache-first fallback (unlike `unitsListProvider`) — there is nothing
/// to fall back to, by this feature's own design decision (see
/// `settings_repository.dart`'s doc comment). `autoDispose` since this
/// screen is reached rarely, not part of the always-alive home-screen graph.
final settingsProvider = FutureProvider.autoDispose<ShopSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).getSettings();
});

/// Drives the settings screen's Save button — same `AsyncNotifier` shape as
/// `CreateUnitController`. `state.error` (a `SettingsPermissionDeniedException`/
/// `SettingsConflictException`/anything else) is read directly by the
/// screen to choose the right message, rather than this controller
/// pre-formatting text a widget test would then have to match verbatim.
class SaveSettingsController extends AsyncNotifier<ShopSettings?> {
  @override
  FutureOr<ShopSettings?> build() => null;

  Future<void> save({
    required ShopSettings base,
    String? taxMode,
    int? taxRateBasisPoints,
    String? pricingMode,
    String? roundingRule,
    String? currencyCode,
    int? lowStockThresholdQuantity,
    int? discountAutoApprovalThresholdMinorUnits,
    int? returnAutoApprovalThresholdMinorUnits,
    String? footerMessage,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(settingsRepositoryProvider)
          .updateSettings(
            clientOperationId: const Uuid().v4(),
            baseUpdatedAt: base.updatedAt,
            taxMode: taxMode,
            taxRateBasisPoints: taxRateBasisPoints,
            pricingMode: pricingMode,
            roundingRule: roundingRule,
            currencyCode: currencyCode,
            lowStockThresholdQuantity: lowStockThresholdQuantity,
            discountAutoApprovalThresholdMinorUnits: discountAutoApprovalThresholdMinorUnits,
            returnAutoApprovalThresholdMinorUnits: returnAutoApprovalThresholdMinorUnits,
            footerMessage: footerMessage,
          ),
    );
    // Refetch on success, and on a conflict too — conflict-resolution.md
    // §4's own "the caller re-fetches and re-applies" policy, applied here
    // by simply discarding the stale form and showing the server's current
    // state once `settingsProvider` resolves again (screen's own `ValueKey`
    // handles resetting the form fields).
    final error = state.error;
    if (!state.hasError || error is SettingsConflictException) {
      ref.invalidate(settingsProvider);
    }
  }
}

final saveSettingsControllerProvider =
    AsyncNotifierProvider<SaveSettingsController, ShopSettings?>(
      SaveSettingsController.new,
    );
