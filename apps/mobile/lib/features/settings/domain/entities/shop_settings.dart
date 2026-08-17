/// Mirrors `GET`/`PATCH /api/v1/settings`'s role-shaped response
/// (docs/modules/settings/specification.md §4) — the two threshold fields
/// are `null` when the caller is a Cashier (omitted by the server
/// entirely, not zeroed) rather than always present. `receipt_template_config`
/// is flattened to its one field, `footerMessage` (M4 item 4) — the object
/// itself currently has no other content worth modelling. `printer_config`
/// is deliberately not modelled here at all: "which printer is paired"
/// stays mobile-local (see `receipt_printing/data/paired_printer_repository.dart`),
/// never round-tripped through this shop-wide row — see
/// `settings/specification.md` §1's Sprint 39 design decision.
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
    this.footerMessage,
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

  /// `null` when never configured — `ReceiptFormatter` falls back to its
  /// own hard-coded default in that case, same as before this field existed.
  final String? footerMessage;
}
