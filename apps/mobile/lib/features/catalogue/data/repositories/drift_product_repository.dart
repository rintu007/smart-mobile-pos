import 'dart:convert';

import 'package:drift/drift.dart';

// `database.dart`'s Drift-generated row class for the `Products` table is
// also named `Product`, colliding with this feature's own domain entity of
// the same name — hidden here since this file never needs the generated
// class, only the table/companion accessors.
import '../../../../core/database/database.dart' hide Product;
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

/// Concrete implementation, per mobile-structure.md §2. No separate
/// `data_sources/` split — there is only one data source (the local Drift
/// database); nothing here calls the network directly, matching
/// sync-architecture.md's "the local write path is the one and only way
/// any entity is created or changed on-device."
class DriftProductRepository implements ProductRepository {
  DriftProductRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Product> createProduct({
    required String id,
    required String name,
    required int priceMinorUnits,
  }) {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.products,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing != null) {
        return Product(
          id: existing.id,
          name: existing.name,
          priceMinorUnits: existing.priceMinorUnits,
        );
      }

      await _db
          .into(_db.products)
          .insert(
            ProductsCompanion.insert(
              id: id,
              name: name,
              priceMinorUnits: priceMinorUnits,
            ),
          );

      // Payload matches POST /api/v1/products' own request shape exactly —
      // sync-api.md §1: "push does not define a second, parallel request
      // schema" — so the future sync engine can hand this straight to the
      // same service logic the direct endpoint uses.
      final payload = jsonEncode({
        'id': id,
        'name': name,
        'price_minor_units': priceMinorUnits,
      });
      await _db
          .into(_db.outboundQueue)
          .insert(
            OutboundQueueCompanion.insert(
              clientOperationId: id,
              entityType: 'product.create',
              payload: payload,
            ),
          );

      return Product(id: id, name: name, priceMinorUnits: priceMinorUnits);
    });
  }

  @override
  Future<List<Product>> listAll() async {
    final rows =
        await (_db.select(_db.products)..orderBy([
          (t) => OrderingTerm(expression: t.name),
        ])).get();
    return rows
        .map(
          (row) => Product(
            id: row.id,
            name: row.name,
            priceMinorUnits: row.priceMinorUnits,
          ),
        )
        .toList();
  }
}
