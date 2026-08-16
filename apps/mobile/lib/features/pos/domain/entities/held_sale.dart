/// One entry in the Held Carts list (`/pos/hold`) — sales-workflows.md's
/// WF-005. Deliberately lighter than [SaleDetail]: the list shows enough to
/// pick the right cart (invoice number, item count, total, how long it's
/// been held), not every line item — resuming loads the full line items.
class HeldSale {
  const HeldSale({
    required this.id,
    required this.provisionalInvoiceNumber,
    required this.itemCount,
    required this.grandTotalMinorUnits,
    required this.createdAt,
  });

  final String id;
  final String provisionalInvoiceNumber;
  final int itemCount;
  final int grandTotalMinorUnits;

  /// Nullable only because the `Sales.createdAt` column itself is nullable
  /// (database.dart's migration comment) — every held cart this sprint's
  /// code creates always has one. Used to order the list most-recently-held
  /// first.
  final DateTime? createdAt;
}
