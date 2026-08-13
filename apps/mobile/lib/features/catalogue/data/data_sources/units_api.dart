import 'package:dio/dio.dart';

import '../../domain/entities/unit.dart';

/// `POST /api/v1/units` — docs/modules/units/specification.md §4.
Future<void> createUnitOnServer(
  Dio dio, {
  required String id,
  required String name,
  required String symbol,
  required bool allowsFractional,
}) async {
  await dio.post<void>(
    '/api/v1/units',
    data: {'id': id, 'name': name, 'symbol': symbol, 'allows_fractional': allowsFractional},
  );
}

/// `GET /api/v1/units` — first page only, same reasoning as `fetchCategories`.
Future<List<Unit>> fetchUnits(Dio dio) async {
  final response = await dio.get<Map<String, dynamic>>('/api/v1/units');
  final data = response.data?['data'] as List<dynamic>? ?? const [];
  return data
      .cast<Map<String, dynamic>>()
      .map(
        (json) => Unit(
          id: json['id'] as String,
          name: json['name'] as String,
          symbol: json['symbol'] as String,
          allowsFractional: json['allows_fractional'] as bool,
        ),
      )
      .toList();
}
