import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/catalogue/domain/entities/product.dart';
import 'package:mobile/features/pos/presentation/providers/pos_providers.dart';

void main() {
  const coffee = Product(id: 'product-1', name: 'Filter coffee', priceMinorUnits: 1500);
  const sugar = Product(id: 'product-2', name: 'Sugar', priceMinorUnits: 500);

  test('addProduct adds a new line, or increments an existing line\'s quantity', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(cartControllerProvider.notifier);

    controller.addProduct(coffee);
    expect(container.read(cartControllerProvider), hasLength(1));
    expect(container.read(cartControllerProvider).single.quantity, 1);

    controller.addProduct(coffee);
    expect(container.read(cartControllerProvider), hasLength(1));
    expect(container.read(cartControllerProvider).single.quantity, 2);

    controller.addProduct(sugar);
    expect(container.read(cartControllerProvider), hasLength(2));
  });

  test('decrementProduct decreases quantity, removing the line at zero', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(cartControllerProvider.notifier);

    controller.addProduct(coffee);
    controller.addProduct(coffee);
    controller.decrementProduct('product-1');
    expect(container.read(cartControllerProvider).single.quantity, 1);

    controller.decrementProduct('product-1');
    expect(container.read(cartControllerProvider), isEmpty);
  });

  test('decrementProduct on an absent product is a no-op', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(cartControllerProvider.notifier).decrementProduct('missing');
    expect(container.read(cartControllerProvider), isEmpty);
  });

  test('cartGrandTotalProvider sums line totals', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(cartControllerProvider.notifier);

    controller.addProduct(coffee);
    controller.addProduct(coffee);
    controller.addProduct(sugar);

    expect(container.read(cartGrandTotalProvider), 3500); // 2*1500 + 1*500
  });

  test('clear empties the cart', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(cartControllerProvider.notifier);

    controller.addProduct(coffee);
    controller.clear();
    expect(container.read(cartControllerProvider), isEmpty);
  });
}
