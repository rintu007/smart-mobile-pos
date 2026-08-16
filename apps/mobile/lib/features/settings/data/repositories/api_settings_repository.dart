import '../../domain/entities/shop_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// Concrete implementation — injected function callbacks, same
/// constructor-injection shape `DriftUnitRepository` established, so tests
/// can supply fakes without touching Dio/HTTP at all.
class ApiSettingsRepository implements SettingsRepository {
  ApiSettingsRepository(this._fetch, this._update);

  final Future<ShopSettings> Function() _fetch;
  final Future<ShopSettings> Function({
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
  })
  _update;

  @override
  Future<ShopSettings> getSettings() => _fetch();

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
  }) => _update(
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
  );
}
