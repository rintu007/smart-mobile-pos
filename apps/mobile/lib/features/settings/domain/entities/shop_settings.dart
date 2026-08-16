/// Mirrors `GET`/`PATCH /api/v1/settings`'s role-shaped response
/// (docs/modules/settings/specification.md §4) — the two threshold fields
/// are `null` when the caller is a Cashier (omitted by the server
/// entirely, not zeroed) rather than always present. `printer_config`/
/// `receipt_template_config` are deliberately not modelled here: the server
/// itself rejects any attempt to set them this sprint (M4 item 4's own
/// scope), so there is nothing for this screen to read or write yet.
class ShopSettings {
  const ShopSettings({
    required this.taxMode,
    required this.taxRateBasisPoints,
    required this.pricingMode,
    required this.roundingRule,
    required this.currencyCode,
    required this.lowStockThresholdQuantity,
    required this.updatedAt,
    this.discountAutoApprovalThresholdMinorUnits,
    this.returnAutoApprovalThresholdMinorUnits,
  });

  final String taxMode;
  final int taxRateBasisPoints;
  final String pricingMode;
  final String roundingRule;
  final String currencyCode;
  final int lowStockThresholdQuantity;
  final DateTime updatedAt;

  /// `null` for a Cashier — the field-level read scope's own signal that
  /// editing must be gated, not a zero value.
  final int? discountAutoApprovalThresholdMinorUnits;
  final int? returnAutoApprovalThresholdMinorUnits;
}
