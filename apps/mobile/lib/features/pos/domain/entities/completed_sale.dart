/// The result of completing a sale locally. `canonical_invoice_number` isn't
/// modelled here at all — it's assigned server-side at sync (ADR-0008), and
/// the sync engine that would ever populate it (backlog.md item 9) doesn't
/// exist yet.
class CompletedSale {
  const CompletedSale({
    required this.id,
    required this.provisionalInvoiceNumber,
    required this.grandTotalMinorUnits,
    required this.completedAt,
  });

  final String id;
  final String provisionalInvoiceNumber;
  final int grandTotalMinorUnits;
  final DateTime completedAt;
}
