import 'package:dio/dio.dart';

import 'store_summary.dart';

/// `GET /api/v1/stores` — docs/11-api/endpoints/identity.md#stores.
/// Response: `{ "data": [{ "id", "name", "address" }], "next_cursor": null }`.
Future<List<StoreSummary>> fetchStores(Dio dio) async {
  final response = await dio.get<Map<String, dynamic>>('/api/v1/stores');
  final data = response.data?['data'] as List<dynamic>? ?? const [];
  return data
      .cast<Map<String, dynamic>>()
      .map((json) => StoreSummary(id: json['id'] as String, name: json['name'] as String))
      .toList();
}
