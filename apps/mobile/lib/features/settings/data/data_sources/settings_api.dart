import 'package:dio/dio.dart';

import '../../domain/entities/shop_settings.dart';
import '../../domain/repositories/settings_repository.dart';

/// `GET /api/v1/settings` — docs/modules/settings/specification.md §4.
Future<ShopSettings> fetchSettings(Dio dio) async {
  final response = await dio.get<Map<String, dynamic>>('/api/v1/settings');
  return _fromJson(response.data!);
}

/// `PATCH /api/v1/settings` — same endpoint, Owner only. A genuine partial
/// update: only the fields the caller passes are sent at all (matching the
/// server's own optional-everything Zod schema), so `/settings/receipt-template`
/// (M4 item 4) can send `footerMessage` alone without also resending every
/// scalar field `/settings` itself edits. Translates the two status codes
/// this screen actually needs to distinguish (§6) into typed exceptions;
/// any other failure (network, 5xx, …) is left as the raw `DioException`,
/// same as every other plain-Dio data source in this codebase (e.g.
/// `units_api.dart`).
Future<ShopSettings> updateSettingsOnServer(
  Dio dio, {
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
  try {
    final response = await dio.patch<Map<String, dynamic>>(
      '/api/v1/settings',
      data: {
        'client_operation_id': clientOperationId,
        'base_updated_at': baseUpdatedAt.toIso8601String(),
        'tax_mode': ?taxMode,
        'tax_rate_basis_points': ?taxRateBasisPoints,
        'pricing_mode': ?pricingMode,
        'rounding_rule': ?roundingRule,
        'currency_code': ?currencyCode,
        'low_stock_threshold_quantity': ?lowStockThresholdQuantity,
        'discount_auto_approval_threshold_minor_units': ?discountAutoApprovalThresholdMinorUnits,
        'return_auto_approval_threshold_minor_units': ?returnAutoApprovalThresholdMinorUnits,
        if (footerMessage != null) 'receipt_template_config': {'footer_message': footerMessage},
      },
    );
    return _fromJson(response.data!);
  } on DioException catch (error) {
    if (error.response?.statusCode == 403) {
      throw const SettingsPermissionDeniedException();
    }
    if (error.response?.statusCode == 409) {
      throw const SettingsConflictException();
    }
    rethrow;
  }
}

ShopSettings _fromJson(Map<String, dynamic> json) {
  final receiptTemplateConfig = json['receipt_template_config'] as Map<String, dynamic>?;
  return ShopSettings(
    taxMode: json['tax_mode'] as String,
    taxRateBasisPoints: json['tax_rate_basis_points'] as int,
    pricingMode: json['pricing_mode'] as String,
    roundingRule: json['rounding_rule'] as String,
    currencyCode: json['currency_code'] as String,
    lowStockThresholdQuantity: json['low_stock_threshold_quantity'] as int,
    updatedAt: DateTime.parse(json['updated_at'] as String),
    discountAutoApprovalThresholdMinorUnits:
        json['discount_auto_approval_threshold_minor_units'] as int?,
    returnAutoApprovalThresholdMinorUnits:
        json['return_auto_approval_threshold_minor_units'] as int?,
    footerMessage: receiptTemplateConfig?['footer_message'] as String?,
  );
}
