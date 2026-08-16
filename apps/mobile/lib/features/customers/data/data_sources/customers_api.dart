import 'package:dio/dio.dart';

import '../../../pos/domain/entities/completed_sale.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_field_conflict.dart';

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

/// `GET /api/v1/customers/conflicts` — Sprint 35 (backlog.md M3 item 5). Manager/Owner only,
/// server-enforced (docs/modules/customers/specification.md §1c) — a Cashier's call throws, left
/// to the caller (`DriftCustomerRepository.listConflicts`) to surface, not swallowed here.
Future<List<CustomerFieldConflict>> fetchConflicts(Dio dio) async {
  final response = await dio.get<Map<String, dynamic>>('/api/v1/customers/conflicts');
  final data = response.data?['data'] as List<dynamic>? ?? const [];
  return data
      .cast<Map<String, dynamic>>()
      .map(
        (json) => CustomerFieldConflict(
          id: json['id'] as String,
          customerId: json['customer_id'] as String,
          customerName: json['customer_name'] as String?,
          field: json['field'] as String,
          currentValue: json['current_value'] as String?,
          currentSetByName: (json['current_set_by'] as Map<String, dynamic>)['display_name'] as String,
          attemptedValue: json['attempted_value'] as String?,
          attemptedSetByName:
              (json['attempted_set_by'] as Map<String, dynamic>)['display_name'] as String,
        ),
      )
      .toList();
}

/// `POST /api/v1/customers/conflicts/{id}/resolve`.
Future<void> resolveConflict(Dio dio, String conflictId, String? resolvedValue) async {
  await dio.post<Map<String, dynamic>>(
    '/api/v1/customers/conflicts/$conflictId/resolve',
    data: {'resolved_value': resolvedValue},
  );
}
