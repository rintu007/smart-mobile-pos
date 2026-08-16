/// A field-edit conflict awaiting a Manager/Owner's decision — the mobile mirror of
/// `GET /customers/conflicts`' response shape. docs/modules/customers/specification.md §1c.
/// Fetched live, online-only — no local cache (the same stance
/// docs/modules/returns/specification.md §1b already established for the returns-approvals queue).
class CustomerFieldConflict {
  const CustomerFieldConflict({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.field,
    required this.currentValue,
    required this.currentSetByName,
    required this.attemptedValue,
    required this.attemptedSetByName,
  });

  final String id;
  final String customerId;
  final String? customerName;

  /// 'name' | 'phone'.
  final String field;
  final String? currentValue;
  final String currentSetByName;
  final String? attemptedValue;
  final String attemptedSetByName;
}
