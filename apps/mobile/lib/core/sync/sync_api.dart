import 'package:dio/dio.dart';

import 'sync_dto.dart';

/// `POST /api/v1/sync/push` — docs/modules/sync-engine/specification.md §4.
/// Never throws for a per-operation rejection — the endpoint itself always
/// answers `200` with one result per operation (sync-api.md §3); a thrown
/// `DioException` here means the request itself failed (no connectivity, an
/// expired session, ...), not that any operation was rejected.
Future<SyncPushResponse> pushSyncOperations(
  Dio dio,
  List<QueuedOperation> operations,
) async {
  final response = await dio.post<Map<String, dynamic>>(
    '/api/v1/sync/push',
    data: {
      'operations': operations
          .map(
            (op) => {
              'type': op.type,
              'client_operation_id': op.clientOperationId,
              'payload': op.payload,
            },
          )
          .toList(),
    },
  );

  final results = (response.data?['results'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()
      .map((json) {
        final error = json['error'] as Map<String, dynamic>?;
        return SyncPushOperationResult(
          clientOperationId: json['client_operation_id'] as String,
          status: json['status'] as String,
          errorCode: error?['code'] as String?,
          errorMessage: error?['message'] as String?,
        );
      })
      .toList();

  return SyncPushResponse(results);
}

/// `GET /api/v1/sync/pull?entity_type=products` — one page.
Future<SyncPullPage> pullProductsPage(Dio dio, {String? cursor}) async {
  final response = await dio.get<Map<String, dynamic>>(
    '/api/v1/sync/pull',
    queryParameters: {'entity_type': 'products', 'cursor': ?cursor},
  );

  final data = response.data?['data'] as List<dynamic>? ?? const [];
  final products = data
      .cast<Map<String, dynamic>>()
      .map(
        (json) => PulledProduct(
          id: json['id'] as String,
          name: json['name'] as String,
          priceMinorUnits: json['price_minor_units'] as int,
        ),
      )
      .toList();

  return SyncPullPage(
    products: products,
    nextCursor: response.data?['next_cursor'] as String?,
  );
}
