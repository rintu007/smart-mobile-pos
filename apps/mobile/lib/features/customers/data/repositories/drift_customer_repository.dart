import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

// `database.dart`'s Drift-generated row class for the `Customers` table is
// also named `Customer`, colliding with this feature's own domain entity of
// the same name — same collision, same fix, as `drift_product_repository.dart`.
import '../../../../core/database/database.dart' hide Customer;
import '../../../pos/domain/entities/completed_sale.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_field_conflict.dart';
import '../../domain/repositories/customer_repository.dart';

/// Concrete implementation, per mobile-structure.md §2. `createCustomer`/
/// `updateCustomer` follow `DriftProductRepository`'s local-write-plus-
/// outbound_queue shape (real sync-push operation types exist —
/// `customer.create`/`customer.update`, docs/modules/customers/
/// specification.md §1a/§1c), **not** `DriftCategoryRepository`'s
/// online-only direct-call shape. Reads (`searchByPhone`/`refreshFromServer`/
/// `getPurchaseHistory`/`listConflicts`/`resolveConflict`) call the network
/// via injected functions, not a raw `Dio` — the same testability reasoning
/// `DriftCategoryRepository`'s own docstring already established (fakeable
/// in tests without a real/fake HTTP client).
class DriftCustomerRepository implements CustomerRepository {
  DriftCustomerRepository(
    this._db,
    this._fetchAll,
    this._fetchPurchaseHistory,
    this._fetchConflicts,
    this._resolveConflictRemote,
  );

  final AppDatabase _db;
  final Future<List<Customer>> Function() _fetchAll;
  final Future<List<CompletedSale>> Function(String customerId) _fetchPurchaseHistory;
  final Future<List<CustomerFieldConflict>> Function() _fetchConflicts;
  final Future<void> Function(String conflictId, String? resolvedValue) _resolveConflictRemote;

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

  @override
  Future<Customer> updateCustomer({required String id, String? name, String? phone}) {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.customers,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final baseName = existing?.name;
      final basePhone = existing?.phone;
      final baseUpdatedAt = existing?.updatedAt ?? DateTime.now();

      await _db
          .into(_db.customers)
          .insertOnConflictUpdate(
            CustomersCompanion(
              id: Value(id),
              name: Value(name),
              phone: Value(phone),
              updatedAt: Value(DateTime.now()),
            ),
          );

      // Payload matches the upgraded PATCH /api/v1/customers/{id}'s own request shape exactly
      // (docs/modules/customers/specification.md §1c/§5) plus `id` — no URL in a push batch, the
      // same structural reason return.approve/return.reject's own sync payloads already
      // established. `base_name`/`base_phone` are the pre-edit local row's own values — the
      // field-level 3-way merge's required inputs.
      final payload = jsonEncode({
        'id': id,
        'base_updated_at': baseUpdatedAt.toIso8601String(),
        'base_name': baseName,
        'base_phone': basePhone,
        'name': name,
        'phone': phone,
      });
      // A random operation id, not the customer's own — an edit is a state transition, not a
      // creation, and a customer can be edited many times, each needing its own operation id (the
      // same reasoning `return.approve`/`return.reject`'s own enqueue already established).
      await _db
          .into(_db.outboundQueue)
          .insert(
            OutboundQueueCompanion.insert(
              clientOperationId: const Uuid().v4(),
              entityType: 'customer.update',
              payload: payload,
            ),
          );

      return Customer(id: id, name: name, phone: phone);
    });
  }

  @override
  Future<List<CustomerFieldConflict>> listConflicts() {
    return _fetchConflicts();
  }

  @override
  Future<void> resolveConflict({required String conflictId, required String? resolvedValue}) {
    return _resolveConflictRemote(conflictId, resolvedValue);
  }
}
