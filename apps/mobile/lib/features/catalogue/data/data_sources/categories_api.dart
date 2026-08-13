import 'package:dio/dio.dart';

import '../../domain/entities/category.dart';

/// `POST /api/v1/categories` — docs/modules/categories/specification.md §4.
/// Idempotent on `id`; the response body is discarded since the caller
/// already knows `id`/`name` and the local cache write uses those directly.
Future<void> createCategoryOnServer(Dio dio, {required String id, required String name}) async {
  await dio.post<void>('/api/v1/categories', data: {'id': id, 'name': name});
}

/// `GET /api/v1/categories` — first page only (default `limit`), matching
/// that endpoint's own "a shop has dozens, not thousands" note
/// (catalogue.md). Response: `{ "data": [{ "id", "name", ... }], "next_cursor" }`.
Future<List<Category>> fetchCategories(Dio dio) async {
  final response = await dio.get<Map<String, dynamic>>('/api/v1/categories');
  final data = response.data?['data'] as List<dynamic>? ?? const [];
  return data
      .cast<Map<String, dynamic>>()
      .map((json) => Category(id: json['id'] as String, name: json['name'] as String))
      .toList();
}
