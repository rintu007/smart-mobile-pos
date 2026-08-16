import 'package:dio/dio.dart';

import '../../../pos/domain/entities/completed_sale.dart';
import '../../domain/entities/customer.dart';

/// `GET /api/v1/customers` — first page only (default `limit`), matching
/// `fetchCategories`'s own "a shop has dozens, not thousands" precedent.
/// Response: `{ "data": [{ "id", "name", "phone", ... }], "next_cursor" }`.
Future<List<Customer>> fetchCustomers(Dio dio) async {
  final response = await dio.get<Map<String, dynamic>>('/api/v1/customers');
  final data = response.data?['data'] as List<dynamic>? ?? const [];
  return data
      .cast<Map<String, dynamic>>()
      .map(
        (json) => Customer(
          id: json['id'] as String,
          name: json['name'] as String?,
          phone: json['phone'] as String?,
        ),
      )
      .toList();
}

/// `GET /api/v1/customers/{id}/purchase-history` — first page only, matching
/// this feature's other reads. Response shape matches `GET /sales`' own
/// convention, so this maps into `pos`'s existing `CompletedSale`.
Future<List<CompletedSale>> fetchPurchaseHistory(Dio dio, String customerId) async {
  final response = await dio.get<Map<String, dynamic>>(
    '/api/v1/customers/$customerId/purchase-history',
  );
  final data = response.data?['data'] as List<dynamic>? ?? const [];
  return data
      .cast<Map<String, dynamic>>()
      .map(
        (json) => CompletedSale(
          id: json['id'] as String,
          provisionalInvoiceNumber: json['provisional_invoice_number'] as String,
          grandTotalMinorUnits: json['grand_total_minor_units'] as int,
          completedAt: DateTime.parse(json['completed_at'] as String),
        ),
      )
      .toList();
}
