import 'dart:convert';

import 'package:drift/drift.dart';

// `database.dart`'s Drift-generated row class for the `Customers` table is
// also named `Customer`, colliding with this feature's own domain entity of
// the same name — same collision, same fix, as `drift_product_repository.dart`.
import '../../../../core/database/database.dart' hide Customer;
import '../../../pos/domain/entities/completed_sale.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';

/// Concrete implementation, per mobile-structure.md §2. `createCustomer`
/// follows `DriftProductRepository`'s local-write-plus-outbound_queue shape
/// (a real sync-push operation type exists — `customer.create`,
/// docs/modules/customers/specification.md §1a), **not**
/// `DriftCategoryRepository`'s online-only direct-call shape. Reads
/// (`searchByPhone`/`refreshFromServer`/`getPurchaseHistory`) call the
/// network via injected functions, not a raw `Dio` — the same testability
/// reasoning `DriftCategoryRepository`'s own docstring already established
/// (fakeable in tests without a real/fake HTTP client).
class DriftCustomerRepository implements CustomerRepository {
  DriftCustomerRepository(this._db, this._fetchAll, this._fetchPurchaseHistory);

  final AppDatabase _db;
  final Future<List<Customer>> Function() _fetchAll;
  final Future<List<CompletedSale>> Function(String customerId) _fetchPurchaseHistory;

  @override
  Future<Customer> createCustomer({required String id, String? name, String? phone}) {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing != null) {
        return Customer(id: existing.id, name: existing.name, phone: existing.phone);
      }

      await _db
          .into(_db.customers)
          .insert(
            CustomersCompanion.insert(
              id: id,
              name: Value(name),
              phone: Value(phone),
            ),
          );

      // Payload matches POST /api/v1/customers' own request shape exactly —
      // sync-api.md §1, mirroring DriftProductRepository's precedent.
      final payload = jsonEncode({
        'id': id,
        'name': ?name,
        'phone': ?phone,
      });
      await _db
          .into(_db.outboundQueue)
          .insert(
            OutboundQueueCompanion.insert(
              clientOperationId: id,
              entityType: 'customer.create',
              payload: payload,
            ),
          );

      return Customer(id: id, name: name, phone: phone);
    });
  }

  @override
  Future<List<Customer>> searchByPhone(String query) async {
    final trimmed = query.trim();
    final select = _db.select(_db.customers)
      ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);
    if (trimmed.isNotEmpty) {
      select.where((t) => t.phone.like('$trimmed%'));
    }
    final rows = await select.get();
    return rows.map((row) => Customer(id: row.id, name: row.name, phone: row.phone)).toList();
  }

  @override
  Future<Customer?> findById(String id) async {
    final row = await (_db.select(
      _db.customers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return Customer(id: row.id, name: row.name, phone: row.phone);
  }

  @override
  Future<void> refreshFromServer() async {
    final customers = await _fetchAll();
    for (final customer in customers) {
      await _db
          .into(_db.customers)
          .insertOnConflictUpdate(
            CustomersCompanion.insert(
              id: customer.id,
              name: Value(customer.name),
              phone: Value(customer.phone),
            ),
          );
    }
  }

  @override
  Future<List<CompletedSale>> getPurchaseHistory(String customerId) {
    return _fetchPurchaseHistory(customerId);
  }
}
