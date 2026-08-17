import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/settings/domain/entities/shop_settings.dart';
import 'package:mobile/features/settings/domain/repositories/settings_repository.dart';
import 'package:mobile/features/settings/presentation/providers/settings_providers.dart';
import 'package:mobile/features/settings/presentation/screens/receipt_template_screen.dart';

/// A fake, not a mock, matching this codebase's own established convention.
class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({this.updateSettingsError, this.onUpdate});

  final Object? updateSettingsError;
  final void Function({String? footerMessage})? onUpdate;

  @override
  Future<ShopSettings> getSettings() async => _settings;

  @override
  Future<ShopSettings> updateSettings({
    required String clientOperationId,
    required DateTime baseUpdatedAt,
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
    onUpdate?.call(footerMessage: footerMessage);
    if (updateSettingsError != null) throw updateSettingsError!;
    return _settings;
  }
}

final _settings = ShopSettings(
  taxMode: 'standard',
  taxRateBasisPoints: 500,
  pricingMode: 'inclusive',
  roundingRule: 'round_half_up',
  currencyCode: 'INR',
  lowStockThresholdQuantity: 5,
  updatedAt: DateTime.utc(2026, 8, 16, 10),
  footerMessage: 'Thank you, visit again!',
);

Widget _wrap({required SettingsRepository repository}) {
  return ProviderScope(
    overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: ReceiptTemplateScreen()),
  );
}

void main() {
  testWidgets('pre-fills the footer field from the loaded settings', (tester) async {
    await tester.pumpWidget(_wrap(repository: _FakeSettingsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Thank you, visit again!'), findsOneWidget);
  });

  testWidgets('sends only footerMessage, never the other scalar fields (true partial update)', (
    tester,
  ) async {
    Map<String, Object?>? captured;
    await tester.pumpWidget(
      _wrap(
        repository: _FakeSettingsRepository(
          onUpdate: ({footerMessage}) => captured = {'footerMessage': footerMessage},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('receipt_template_footer_field')),
      'See you soon!',
    );
    await tester.tap(find.byKey(const Key('receipt_template_save_button')));
    await tester.pumpAndSettle();

    expect(captured, {'footerMessage': 'See you soon!'});
    expect(find.byKey(const Key('receipt_template_error_text')), findsNothing);
  });

  testWidgets('rejects an empty footer message client-side', (tester) async {
    var updateCalled = false;
    await tester.pumpWidget(
      _wrap(repository: _FakeSettingsRepository(onUpdate: ({footerMessage}) => updateCalled = true)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('receipt_template_footer_field')), '   ');
    await tester.tap(find.byKey(const Key('receipt_template_save_button')));
    await tester.pumpAndSettle();

    expect(updateCalled, isFalse);
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

    await tester.tap(find.byKey(const Key('receipt_template_save_button')));
    await tester.pumpAndSettle();

    expect(find.text('Only the Owner can change the receipt template.'), findsOneWidget);
  });
}
