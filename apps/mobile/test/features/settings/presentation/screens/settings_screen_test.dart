import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/settings/domain/entities/shop_settings.dart';
import 'package:mobile/features/settings/domain/repositories/settings_repository.dart';
import 'package:mobile/features/settings/presentation/providers/settings_providers.dart';
import 'package:mobile/features/settings/presentation/screens/settings_screen.dart';

/// A fake, not a mock, matching this codebase's own established convention
/// (`_FakeReportsRepository`).
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({
    this.getSettingsResult,
    this.getSettingsNeverCompletes = false,
    this.getSettingsError,
    this.updateSettingsError,
    this.onUpdate,
  });

  final ShopSettings? getSettingsResult;
  final bool getSettingsNeverCompletes;
  final Object? getSettingsError;
  final Object? updateSettingsError;
  final void Function({
    required String taxMode,
    required int taxRateBasisPoints,
    required String pricingMode,
    required String roundingRule,
    required String currencyCode,
    required int lowStockThresholdQuantity,
    int? discountAutoApprovalThresholdMinorUnits,
    int? returnAutoApprovalThresholdMinorUnits,
  })?
  onUpdate;

  @override
  Future<ShopSettings> getSettings() async {
    if (getSettingsNeverCompletes) return Completer<ShopSettings>().future;
    if (getSettingsError != null) throw getSettingsError!;
    return getSettingsResult ?? ownerSettings;
  }

  @override
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
  }) async {
    onUpdate?.call(
      taxMode: taxMode,
      taxRateBasisPoints: taxRateBasisPoints,
      pricingMode: pricingMode,
      roundingRule: roundingRule,
      currencyCode: currencyCode,
      lowStockThresholdQuantity: lowStockThresholdQuantity,
      discountAutoApprovalThresholdMinorUnits: discountAutoApprovalThresholdMinorUnits,
      returnAutoApprovalThresholdMinorUnits: returnAutoApprovalThresholdMinorUnits,
    );
    if (updateSettingsError != null) throw updateSettingsError!;
    return ownerSettings;
  }
}

final ownerSettings = ShopSettings(
  taxMode: 'standard',
  taxRateBasisPoints: 500,
  pricingMode: 'inclusive',
  roundingRule: 'round_half_up',
  currencyCode: 'INR',
  lowStockThresholdQuantity: 5,
  updatedAt: DateTime.utc(2026, 8, 16, 10),
  discountAutoApprovalThresholdMinorUnits: 50000,
  returnAutoApprovalThresholdMinorUnits: 100000,
);

final cashierSettings = ShopSettings(
  taxMode: 'unregistered',
  taxRateBasisPoints: 0,
  pricingMode: 'inclusive',
  roundingRule: 'round_half_up',
  currencyCode: 'INR',
  lowStockThresholdQuantity: 5,
  updatedAt: DateTime.utc(2026, 8, 16, 10),
);

Widget _wrap({required SettingsRepository repository}) {
  return ProviderScope(
    overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  testWidgets('shows a loading indicator while settings are still resolving', (tester) async {
    await tester.pumpWidget(
      _wrap(repository: _FakeSettingsRepository(getSettingsNeverCompletes: true)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows an error state when settings fail to load', (tester) async {
    await tester.pumpWidget(
      _wrap(repository: _FakeSettingsRepository(getSettingsError: Exception('boom'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load settings. Try again.'), findsOneWidget);
  });

  testWidgets('renders both auto-approval thresholds for an Owner/Manager response', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(repository: _FakeSettingsRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_tax_mode_field')), findsOneWidget);
    expect(find.byKey(const Key('settings_discount_threshold_field')), findsOneWidget);
    expect(find.byKey(const Key('settings_return_threshold_field')), findsOneWidget);
  });

  testWidgets('omits both auto-approval thresholds for a Cashier response', (tester) async {
    await tester.pumpWidget(
      _wrap(repository: _FakeSettingsRepository(getSettingsResult: cashierSettings)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings_tax_mode_field')), findsOneWidget);
    expect(find.byKey(const Key('settings_discount_threshold_field')), findsNothing);
    expect(find.byKey(const Key('settings_return_threshold_field')), findsNothing);
  });

  testWidgets('saves successfully and shows no error', (tester) async {
    Map<String, Object?>? captured;
    await tester.pumpWidget(
      _wrap(
        repository: _FakeSettingsRepository(
          onUpdate:
              ({
                required taxMode,
                required taxRateBasisPoints,
                required pricingMode,
                required roundingRule,
                required currencyCode,
                required lowStockThresholdQuantity,
                discountAutoApprovalThresholdMinorUnits,
                returnAutoApprovalThresholdMinorUnits,
              }) {
                captured = {
                  'taxMode': taxMode,
                  'taxRateBasisPoints': taxRateBasisPoints,
                  'currencyCode': currencyCode,
                };
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings_save_button')));
    await tester.tap(find.byKey(const Key('settings_save_button')));
    await tester.pumpAndSettle();

    expect(captured, {'taxMode': 'standard', 'taxRateBasisPoints': 500, 'currencyCode': 'INR'});
    expect(find.byKey(const Key('settings_error_text')), findsNothing);
  });

  testWidgets('shows an Owner-only message on a 403', (tester) async {
    await tester.pumpWidget(
      _wrap(
        repository: _FakeSettingsRepository(
          updateSettingsError: const SettingsPermissionDeniedException(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings_save_button')));
    await tester.tap(find.byKey(const Key('settings_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Only the Owner can change settings.'), findsOneWidget);
  });

  testWidgets('shows a conflict message on a 409', (tester) async {
    await tester.pumpWidget(
      _wrap(
        repository: _FakeSettingsRepository(updateSettingsError: const SettingsConflictException()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings_save_button')));
    await tester.tap(find.byKey(const Key('settings_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Someone else changed these settings. Refresh and try again.'), findsOneWidget);
  });

  testWidgets('blocks submission client-side when tax rate is nonzero outside Standard mode', (
    tester,
  ) async {
    var updateCalled = false;
    await tester.pumpWidget(
      _wrap(
        repository: _FakeSettingsRepository(onUpdate: ({required taxMode, required taxRateBasisPoints, required pricingMode, required roundingRule, required currencyCode, required lowStockThresholdQuantity, discountAutoApprovalThresholdMinorUnits, returnAutoApprovalThresholdMinorUnits}) {
          updateCalled = true;
        }),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings_tax_mode_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unregistered').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings_save_button')));
    await tester.tap(find.byKey(const Key('settings_save_button')));
    await tester.pumpAndSettle();

    expect(updateCalled, isFalse);
    expect(find.text('Tax rate must be 0 unless tax mode is Standard.'), findsOneWidget);
  });
}
