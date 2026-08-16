import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/database/database.dart' hide Product;
import 'package:mobile/core/store_context/store_context_providers.dart';
import 'package:mobile/features/catalogue/domain/entities/product.dart';
import 'package:mobile/features/pos/domain/entities/cart_line.dart';
import 'package:mobile/features/pos/domain/entities/resumed_cart.dart';
import 'package:mobile/features/pos/presentation/providers/pos_providers.dart';

// Sprint 30 (backlog.md M2 item 6, Hold/Resume): `CartController` now
// persists through `saleRepositoryProvider` (-> `appDatabaseProvider`) and
// reads `storeContextProvider` on every mutation, so these tests need real
// overrides for both — a real in-memory Drift DB (matching
// drift_sale_repository_test.dart's own precedent of exercising real SQL,
// not a fake, for the persistence layer itself), and a fixed store id.
void main() {
  const coffee = Product(id: 'product-1', name: 'Filter coffee', priceMinorUnits: 1500);
  const sugar = Product(id: 'product-2', name: 'Sugar', priceMinorUnits: 500);
  const storeId = 'store-1';

  ProviderContainer makeContainer() {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        storeContextProvider.overrideWith((ref) async => storeId),
      ],
    );
  }

  test('addProduct adds a new line, or increments an existing line\'s quantity', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(cartControllerProvider.notifier);

    await controller.addProduct(coffee);
    expect(container.read(cartControllerProvider).lines, hasLength(1));
    expect(container.read(cartControllerProvider).lines.single.quantity, 1);

    await controller.addProduct(coffee);
    expect(container.read(cartControllerProvider).lines, hasLength(1));
    expect(container.read(cartControllerProvider).lines.single.quantity, 2);

    await controller.addProduct(sugar);
    expect(container.read(cartControllerProvider).lines, hasLength(2));
  });

  test('addProduct persists a draft row locally', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final db = container.read(appDatabaseProvider);

    await container.read(cartControllerProvider.notifier).addProduct(coffee);

    final draftId = container.read(cartControllerProvider).draftId;
    expect(draftId, isNotNull);
    final row = await (db.select(db.sales)..where((t) => t.id.equals(draftId!))).getSingle();
    expect(row.status, 'draft');
    expect(row.grandTotalMinorUnits, 1500);
  });

  test('decrementProduct decreases quantity, removing the line at zero', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(cartControllerProvider.notifier);

    await controller.addProduct(coffee);
    await controller.addProduct(coffee);
    await controller.decrementProduct('product-1');
    expect(container.read(cartControllerProvider).lines.single.quantity, 1);

    await controller.decrementProduct('product-1');
    expect(container.read(cartControllerProvider).lines, isEmpty);
    expect(container.read(cartControllerProvider).draftId, isNull);
  });

  test(
    'decrementing the last line deletes the draft row, not merely clearing in-memory state',
    () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);
      final controller = container.read(cartControllerProvider.notifier);

      await controller.addProduct(coffee);
      final draftId = container.read(cartControllerProvider).draftId!;
      await controller.decrementProduct('product-1');

      expect(
        await (db.select(db.sales)..where((t) => t.id.equals(draftId))).getSingleOrNull(),
        isNull,
      );
    },
  );

  test('decrementProduct on an absent product is a no-op', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(cartControllerProvider.notifier).decrementProduct('missing');
    expect(container.read(cartControllerProvider).lines, isEmpty);
  });

  test('cartGrandTotalProvider sums line totals', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(cartControllerProvider.notifier);

    await controller.addProduct(coffee);
    await controller.addProduct(coffee);
    await controller.addProduct(sugar);

    expect(container.read(cartGrandTotalProvider), 3500); // 2*1500 + 1*500
  });

  test('clear empties the in-memory cart', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    final controller = container.read(cartControllerProvider.notifier);

    await controller.addProduct(coffee);
    controller.clear();
    expect(container.read(cartControllerProvider).lines, isEmpty);
    expect(container.read(cartControllerProvider).draftId, isNull);
  });

  group('hold / loadResumed', () {
    test('hold clears the active cart and marks the row held', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);
      final controller = container.read(cartControllerProvider.notifier);

      await controller.addProduct(coffee);
      final draftId = container.read(cartControllerProvider).draftId!;
      await controller.hold();

      expect(container.read(cartControllerProvider).lines, isEmpty);
      expect(container.read(cartControllerProvider).draftId, isNull);
      final row = await (db.select(db.sales)..where((t) => t.id.equals(draftId))).getSingle();
      expect(row.status, 'held');
    });

    test('hold on an empty cart is a no-op', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await container.read(cartControllerProvider.notifier).hold();

      expect(await db.select(db.sales).get(), isEmpty);
    });

    test(
      'loadResumed while a different cart is active implicitly holds the active one first',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);
        final db = container.read(appDatabaseProvider);
        final controller = container.read(cartControllerProvider.notifier);

        await controller.addProduct(coffee);
        final activeDraftId = container.read(cartControllerProvider).draftId!;

        await controller.loadResumed(
          'held-sale-1',
          const ResumedCart(
            lines: [
              CartLine(
                productId: 'product-2',
                productName: 'Sugar',
                unitPriceMinorUnits: 500,
                quantity: 1,
              ),
            ],
          ),
        );

        expect(container.read(cartControllerProvider).draftId, 'held-sale-1');
        expect(container.read(cartControllerProvider).lines.single.productId, 'product-2');
        final activeRow = await (db.select(
          db.sales,
        )..where((t) => t.id.equals(activeDraftId))).getSingle();
        expect(
          activeRow.status,
          'held',
          reason: 'the cart that was active before resuming must not be silently discarded',
        );
      },
    );

    test('loadResumed with no prior active cart just sets the resumed one active', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await container.read(cartControllerProvider.notifier).loadResumed(
        'held-sale-1',
        const ResumedCart(
          lines: [
            CartLine(
              productId: 'product-2',
              productName: 'Sugar',
              unitPriceMinorUnits: 500,
              quantity: 1,
            ),
          ],
        ),
      );

      expect(container.read(cartControllerProvider).draftId, 'held-sale-1');
      expect(container.read(cartControllerProvider).lines, hasLength(1));
    });
  });

  // Sprint 32 (backlog.md M3 item 2).
  group('attachCustomer / removeCustomer', () {
    test('attaching a customer to a non-empty cart persists it on the draft row', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);
      final controller = container.read(cartControllerProvider.notifier);

      await controller.addProduct(coffee);
      await controller.attachCustomer(
        customerId: 'customer-1',
        customerName: 'Ramesh Kumar',
        customerPhone: '9876543210',
      );

      expect(container.read(cartControllerProvider).customerId, 'customer-1');
      expect(container.read(cartControllerProvider).customerName, 'Ramesh Kumar');
      final draftId = container.read(cartControllerProvider).draftId!;
      final row = await (db.select(db.sales)..where((t) => t.id.equals(draftId))).getSingle();
      expect(row.customerId, 'customer-1');
    });

    test('attaching a customer to an empty cart only sets in-memory state', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);

      await container
          .read(cartControllerProvider.notifier)
          .attachCustomer(customerId: 'customer-1');

      expect(container.read(cartControllerProvider).customerId, 'customer-1');
      expect(await db.select(db.sales).get(), isEmpty);
    });

    test('a customer attached before any item is added survives the first addProduct', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);
      final controller = container.read(cartControllerProvider.notifier);

      await controller.attachCustomer(customerId: 'customer-1');
      await controller.addProduct(coffee);

      final draftId = container.read(cartControllerProvider).draftId!;
      final row = await (db.select(db.sales)..where((t) => t.id.equals(draftId))).getSingle();
      expect(row.customerId, 'customer-1');
    });

    test('removeCustomer detaches the customer and persists the change', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final db = container.read(appDatabaseProvider);
      final controller = container.read(cartControllerProvider.notifier);

      await controller.addProduct(coffee);
      await controller.attachCustomer(customerId: 'customer-1');
      await controller.removeCustomer();

      expect(container.read(cartControllerProvider).customerId, isNull);
      final draftId = container.read(cartControllerProvider).draftId!;
      final row = await (db.select(db.sales)..where((t) => t.id.equals(draftId))).getSingle();
      expect(row.customerId, isNull);
    });
  });
}
