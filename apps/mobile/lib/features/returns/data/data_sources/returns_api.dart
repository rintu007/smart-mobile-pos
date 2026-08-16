import 'package:dio/dio.dart';

import '../../domain/entities/return_detail.dart';
import '../../domain/entities/return_summary.dart';

/// `GET /api/v1/returns` — first page only, matching `fetchCustomers`'s own
/// "a shop has dozens, not thousands" precedent.
Future<List<ReturnSummary>> fetchMyReturns(Dio dio) async {
  final response = await dio.get<Map<String, dynamic>>('/api/v1/returns');
  return _mapSummaries(response.data);
}

/// `GET /api/v1/returns/approvals`.
Future<List<ReturnSummary>> fetchApprovals(Dio dio) async {
  final response = await dio.get<Map<String, dynamic>>('/api/v1/returns/approvals');
  return _mapSummaries(response.data);
}

/// `GET /api/v1/returns/{id}`.
Future<ReturnDetail?> fetchReturnById(Dio dio, String id) async {
  final response = await dio.get<Map<String, dynamic>>('/api/v1/returns/$id');
  return _mapDetail(response.data);
}

List<ReturnSummary> _mapSummaries(Map<String, dynamic>? body) {
  final data = body?['data'] as List<dynamic>? ?? const [];
  return data.cast<Map<String, dynamic>>().map(_mapSummary).toList();
}

ReturnSummary _mapSummary(Map<String, dynamic> json) {
  return ReturnSummary(
    id: json['id'] as String,
    originalSaleId: json['original_sale_id'] as String,
    status: json['status'] as String,
    refundTotalMinorUnits: json['refund_total_minor_units'] as int,
    approvedBy: json['approved_by'] as String?,
    completedAt: json['completed_at'] == null ? null : DateTime.parse(json['completed_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

ReturnDetail? _mapDetail(Map<String, dynamic>? json) {
  if (json == null) return null;
  final lineItems = (json['line_items'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()
      .map(
        (item) => ReturnLineItem(
          originalSaleLineItemId: item['original_sale_line_item_id'] as String,
          quantity: (item['quantity'] as num).toInt(),
          refundAmountMinorUnits: item['refund_amount_minor_units'] as int,
        ),
      )
      .toList();

  return ReturnDetail(
    id: json['id'] as String,
    originalSaleId: json['original_sale_id'] as String,
    status: json['status'] as String,
    refundTotalMinorUnits: json['refund_total_minor_units'] as int,
    approvedBy: json['approved_by'] as String?,
    completedAt: json['completed_at'] == null ? null : DateTime.parse(json['completed_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
    lineItems: lineItems,
  );
}
