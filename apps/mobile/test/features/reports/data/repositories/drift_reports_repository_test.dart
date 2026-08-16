import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/database.dart';
import 'package:mobile/core/database/tables/stock_movements.dart' show MovementType;
import 'package:mobile/features/reports/data/repositories/drift_reports_repository.dart';
import 'package:mobile/features/reports/domain/repositories/reports_repository.dart';

void main() {
  late AppDatabase db;
  late DriftReportsRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftReportsRepository(db);
  });

  tearDown(() => db.close());

  Future<void> insertProduct(String id, {required String name, required int priceMinorUnits}) {
    return db
        .into(db.products)
        .insert(ProductsCompanion.insert(id: id, name: name, priceMinorUnits: priceMinorUnits));
  }

  Future<void> insertMovement(
    String id, {
    required String productId,
    required double quantityDelta,
    required DateTime createdAt,
  }) {
    return db
        .into(db.stockMovements)
        .insert(
          StockMovementsCompanion.insert(
            id: id,
            productId: productId,
            quantityDelta: quantityDelta,
            movementType: MovementType.adjustment,
            createdAt: Value(createdAt),
          ),
        );
  }

  Future<void> insertSale(
    String id, {
    required int grandTotalMinorUnits,
    required DateTime completedAt,
    String status = 'completed',
  }) {
    return db
        .into(db.sales)
        .insert(
          SalesCompanion.insert(
            id: id,
            status: status,
            provisionalInvoiceNumber: 'INV-$id',
            subtotalMinorUnits: grandTotalMinorUnits,
            grandTotalMinorUnits: grandTotalMinorUnits,
            completedAt: Value(completedAt),
          ),
        );
  }

  Future<void> insertLineItem(
    String id, {
    required String saleId,
    required String productId,
    required double quantity,
    required int unitPriceMinorUnits,
    required int lineTotalMinorUnits,
  }) {
    return db
        .into(db.saleLineItems)
        .insert(
          SaleLineItemsCompanion.insert(
            id: id,
            saleId: saleId,
            productId: productId,
            quantity: quantity,
            unitPriceMinorUnits: unitPriceMinorUnits,
            lineTotalMinorUnits: lineTotalMinorUnits,
          ),
        );
  }

  group('dailySales', () {
    test('sums only completed sales, bucketed by calendar day', () async {
      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);
      final yesterday = todayDateOnly.subtract(const Duration(days: 1));

      await insertSale('s1', grandTotalMinorUnits: 1000, completedAt: todayDateOnly.add(const Duration(hours: 9)));
      await insertSale('s2', grandTotalMinorUnits: 500, completedAt: todayDateOnly.add(const Duration(hours: 15)));
      await insertSale('s3', grandTotalMinorUnits: 2000, completedAt: yesterday.add(const Duration(hours: 10)));
      await insertSale('s4', grandTotalMinorUnits: 999999, completedAt: todayDateOnly, status: 'held');

      final entries = await repository.dailySales();

      expect(entries, hasLength(7));
      final todayEntry = entries.last;
      final yesterdayEntry = entries[entries.length - 2];
      expect(todayEntry.totalMinorUnits, 1500);
      expect(yesterdayEntry.totalMinorUnits, 2000);
    });

    test('returns a zero entry for a day with no sales, not an omitted day', () async {
      final entries = await repository.dailySales();
      expect(entries, hasLength(7));
      expect(entries.every((e) => e.totalMinorUnits == 0), true);
    });
  });

  group('stockValue', () {
    test('multiplies each product\'s derived balance by its price and sums', () async {
      await insertProduct('p1', name: 'Coffee', priceMinorUnits: 500);
      await insertProduct('p2', name: 'Sugar', priceMinorUnits: 200);
      await insertMovement('m1', productId: 'p1', quantityDelta: 10, createdAt: DateTime(2026, 8, 1));
      await insertMovement('m2', productId: 'p1', quantityDelta: -3, createdAt: DateTime(2026, 8, 2));
      await insertMovement('m3', productId: 'p2', quantityDelta: 5, createdAt: DateTime(2026, 8, 1));

      final report = await repository.stockValue();

      // p1: balance 7 * 500 = 3500; p2: balance 5 * 200 = 1000.
      expect(report.totalMinorUnits, 4500);
      expect(report.entries, hasLength(2));
      expect(report.entries.first.valueMinorUnits, 3500); // sorted value-descending
    });

    test('a product with no movements at all has zero balance, not excluded', () async {
      await insertProduct('p1', name: 'Coffee', priceMinorUnits: 500);

      final report = await repository.stockValue();

      expect(report.entries, hasLength(1));
      expect(report.entries.single.balance, 0);
      expect(report.totalMinorUnits, 0);
    });
  });

  group('topProducts', () {
    test('ranks by value or quantity, respecting the date range boundary', () async {
      await insertProduct('p1', name: 'Coffee', priceMinorUnits: 500);
      await insertProduct('p2', name: 'Sugar', priceMinorUnits: 200);
      await insertSale('s1', grandTotalMinorUnits: 2500, completedAt: DateTime(2026, 8, 5));
      await insertLineItem('li1', saleId: 's1', productId: 'p1', quantity: 5, unitPriceMinorUnits: 500, lineTotalMinorUnits: 2500);
      await insertSale('s2', grandTotalMinorUnits: 2000, completedAt: DateTime(2026, 8, 6));
      await insertLineItem('li2', saleId: 's2', productId: 'p2', quantity: 10, unitPriceMinorUnits: 200, lineTotalMinorUnits: 2000);
      // Outside the queried range entirely.
      await insertSale('s3', grandTotalMinorUnits: 100000, completedAt: DateTime(2026, 9, 1));
      await insertLineItem('li3', saleId: 's3', productId: 'p1', quantity: 999, unitPriceMinorUnits: 500, lineTotalMinorUnits: 100000);

      final byValue = await repository.topProducts(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
        sortBy: TopProductsSortBy.value,
      );
      final byQuantity = await repository.topProducts(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
        sortBy: TopProductsSortBy.quantity,
      );

      expect(byValue.map((e) => e.productId).toList(), ['p1', 'p2']); // 2500 > 2000
      expect(byQuantity.map((e) => e.productId).toList(), ['p2', 'p1']); // 10 > 5
      expect(byValue.every((e) => e.quantity < 999), true); // September sale excluded
    });

    test('a product with zero quantity sold in range is omitted, not a false zero-row', () async {
      await insertProduct('p1', name: 'Coffee', priceMinorUnits: 500);

      final entries = await repository.topProducts(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
        sortBy: TopProductsSortBy.value,
      );

      expect(entries, isEmpty);
    });
  });

  group('lowStock', () {
    test('includes only products strictly below threshold, sorted furthest-under first', () async {
      await db
          .into(db.shopSettingsCache)
          .insert(
            ShopSettingsCacheCompanion.insert(id: 'current', lowStockThresholdQuantity: const Value(10)),
          );
      await insertProduct('p1', name: 'Coffee', priceMinorUnits: 500); // balance 2 (furthest under)
      await insertProduct('p2', name: 'Sugar', priceMinorUnits: 200); // balance 8
      await insertProduct('p3', name: 'Tea', priceMinorUnits: 300); // balance 20, not low
      await insertMovement('m1', productId: 'p1', quantityDelta: 2, createdAt: DateTime(2026, 8, 1));
      await insertMovement('m2', productId: 'p2', quantityDelta: 8, createdAt: DateTime(2026, 8, 1));
      await insertMovement('m3', productId: 'p3', quantityDelta: 20, createdAt: DateTime(2026, 8, 1));

      final entries = await repository.lowStock();

      expect(entries.map((e) => e.productId).toList(), ['p1', 'p2']);
      expect(entries.every((e) => e.thresholdQuantity == 10), true);
    });

    test('falls back to the server-matching default (5) when no cache row exists yet', () async {
      await insertProduct('p1', name: 'Coffee', priceMinorUnits: 500);
      await insertMovement('m1', productId: 'p1', quantityDelta: 3, createdAt: DateTime(2026, 8, 1));

      final entries = await repository.lowStock();

      expect(entries, hasLength(1));
      expect(entries.single.thresholdQuantity, 5);
    });
  });

  group('canViewReports', () {
    test('defaults to false when no cache row exists yet (fail-closed)', () async {
      expect(await repository.canViewReports(), false);
    });

    test('reflects the cached probe result', () async {
      await db
          .into(db.shopSettingsCache)
          .insert(ShopSettingsCacheCompanion.insert(id: 'current', canViewReports: const Value(true)));

      expect(await repository.canViewReports(), true);
    });
  });
}
