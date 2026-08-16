import 'package:dio/dio.dart';

import '../../domain/entities/sale_detail.dart';

/// Sprint 34 (backlog.md M3 item 4) — the mobile app's first network-backed
/// sale reads; every prior sale operation (`completeSale`, `getSaleDetail`,
/// ...) was purely local. Both functions map the server's `formatSale`
/// response shape (docs/modules/pos/specification.md, shared by
/// `GET /sales/{id}`, `GET /sales/lookup`, and `POST /sales`' own response)
/// into [SaleDetail] — `id` per line item requires the Sprint 34 server
/// correction (docs/modules/returns/specification.md §1b).

/// `GET /api/v1/sales/lookup` — exactly one of the two query params, per the
/// server's own validation.
Future<SaleDetail?> fetchSaleByLookup(
  Dio dio, {
  String? provisionalInvoiceNumber,
  String? canonicalInvoiceNumber,
}) async {
  final response = await dio.get<Map<String, dynamic>>(
    '/api/v1/sales/lookup',
    queryParameters: {
      'provisional_invoice_number': ?provisionalInvoiceNumber,
      'canonical_invoice_number': ?canonicalInvoiceNumber,
    },
  );
  return _mapSaleDetail(response.data);
}

/// `GET /api/v1/sales/{id}`.
Future<SaleDetail?> fetchSaleById(Dio dio, String id) async {
  final response = await dio.get<Map<String, dynamic>>('/api/v1/sales/$id');
  return _mapSaleDetail(response.data);
}

SaleDetail? _mapSaleDetail(Map<String, dynamic>? json) {
  if (json == null) return null;
  final lineItems = (json['line_items'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()
      .map(
        (item) => SaleLineDetail(
          id: item['id'] as String,
          productId: item['product_id'] as String,
          // The server response has no product name (it's a catalogue
          // concern, not a sale-fact) — resolved against the local product
          // cache by the caller, same as `getSaleDetail`'s own local path.
          productName: null,
          quantity: (item['quantity'] as num).toInt(),
          unitPriceMinorUnits: item['unit_price_minor_units'] as int,
          lineTotalMinorUnits: item['line_total_minor_units'] as int,
        ),
      )
      .toList();

  return SaleDetail(
    id: json['id'] as String,
    provisionalInvoiceNumber: json['provisional_invoice_number'] as String,
    completedAt: DateTime.parse(json['completed_at'] as String),
    grandTotalMinorUnits: json['grand_total_minor_units'] as int,
    lines: lineItems,
  );
}
