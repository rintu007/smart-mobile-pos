import 'cart_line.dart';

/// The result of [SaleRepository.resumeSale] — a held cart's line items plus
/// its attached customer, if any (a snapshot for display, not a live
/// reference — the customer's own record may since have changed). Added
/// Sprint 32 (backlog.md M3 item 2), extending Sprint 30's plain
/// `List<CartLine>?` return so the attached customer survives hold/resume,
/// the same durability guarantee FR-026 already requires for line items
/// (docs/modules/customers/specification.md §1a).
class ResumedCart {
  const ResumedCart({required this.lines, this.customerId, this.customerName, this.customerPhone});

  final List<CartLine> lines;
  final String? customerId;
  final String? customerName;
  final String? customerPhone;
}
