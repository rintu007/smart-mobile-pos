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
          categoryId: json['category_id'] as String?,
          unitId: json['unit_id'] as String?,
          sku: json['sku'] as String?,
          barcode: json['barcode'] as String?,
        ),
      )
      .toList();

  return SyncPullPage(
    products: products,
    nextCursor: response.data?['next_cursor'] as String?,
  );
}

/// `GET /api/v1/sync/pull?entity_type=stock_movements` — one page. Added
/// Sprint 36 (backlog.md M4 item 1).
Future<StockMovementPullPage> pullStockMovementsPage(Dio dio, {String? cursor}) async {
  final response = await dio.get<Map<String, dynamic>>(
    '/api/v1/sync/pull',
    queryParameters: {'entity_type': 'stock_movements', 'cursor': ?cursor},
  );

  final data = response.data?['data'] as List<dynamic>? ?? const [];
  final movements = data
      .cast<Map<String, dynamic>>()
      .map(
        (json) => PulledStockMovement(
          id: json['id'] as String,
          productId: json['product_id'] as String,
          quantityDelta: (json['quantity_delta'] as num).toDouble(),
          movementType: json['movement_type'] as String,
          createdAt: DateTime.parse(json['created_at'] as String),
        ),
      )
      .toList();

  return StockMovementPullPage(
    movements: movements,
    nextCursor: response.data?['next_cursor'] as String?,
    hasMore: response.data?['has_more'] as bool? ?? false,
  );
}

/// `GET /api/v1/sync/pull?entity_type=sales` — one page. Added Sprint 36
/// (backlog.md M4 item 1).
Future<SalePullPage> pullSalesPage(Dio dio, {String? cursor}) async {
  final response = await dio.get<Map<String, dynamic>>(
    '/api/v1/sync/pull',
    queryParameters: {'entity_type': 'sales', 'cursor': ?cursor},
  );

  final data = response.data?['data'] as List<dynamic>? ?? const [];
  final sales = data.cast<Map<String, dynamic>>().map((json) {
    final lineItemsJson = json['line_items'] as List<dynamic>? ?? const [];
    return PulledSale(
      id: json['id'] as String,
      status: json['status'] as String,
      provisionalInvoiceNumber: json['provisional_invoice_number'] as String,
      subtotalMinorUnits: json['subtotal_minor_units'] as int,
      grandTotalMinorUnits: json['grand_total_minor_units'] as int,
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      customerId: json['customer_id'] as String?,
      lineItems: lineItemsJson
          .cast<Map<String, dynamic>>()
          .map(
            (item) => PulledSaleLineItem(
              id: item['id'] as String,
              productId: item['product_id'] as String,
              quantity: (item['quantity'] as num).toDouble(),
              unitPriceMinorUnits: item['unit_price_minor_units'] as int,
              lineTotalMinorUnits: item['line_total_minor_units'] as int,
            ),
          )
          .toList(),
    );
  }).toList();

  return SalePullPage(
    sales: sales,
    nextCursor: response.data?['next_cursor'] as String?,
    hasMore: response.data?['has_more'] as bool? ?? false,
  );
}

/// `GET /api/v1/sync/pull?entity_type=shop_settings` — always at most one
/// row, no pagination. Added Sprint 37 (backlog.md M4 item 2).
Future<PulledShopSettings?> pullShopSettings(Dio dio) async {
  final response = await dio.get<Map<String, dynamic>>(
    '/api/v1/sync/pull',
    queryParameters: const {'entity_type': 'shop_settings'},
  );

  final data = response.data?['data'] as List<dynamic>? ?? const [];
  if (data.isEmpty) return null;

  final row = data.first as Map<String, dynamic>;
  return PulledShopSettings(
    lowStockThresholdQuantity: row['low_stock_threshold_quantity'] as int,
  );
}

/// `GET /api/v1/users?limit=1` — already Manager/Owner-only (Sprint 23),
/// reused here purely as a permission probe (docs/modules/reports/
/// specification.md §1's third gap); the response body is discarded, only
/// the status matters. Added Sprint 37 (backlog.md M4 item 2). Swallows
/// every failure (a Cashier's expected `403`, no connectivity, anything
/// else) to `false` — never throws, so `SyncRepository.syncNow()` can call
/// it unconditionally alongside its other pull steps.
Future<bool> probeCanViewReports(Dio dio) async {
  try {
    await dio.get<Map<String, dynamic>>(
      '/api/v1/users',
      queryParameters: const {'limit': 1},
    );
    return true;
  } on DioException {
    return false;
  }
}
