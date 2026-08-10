import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../providers/pos_providers.dart';

/// `/pos`, per route-map.md — backlog.md item 6's till screen. No design-
/// system composition spec exists yet beyond patterns.md's generic list/
/// button states, same reasoning `AddProductScreen` already used.
class TillScreen extends ConsumerWidget {
  const TillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productListProvider);
    final cartLines = ref.watch(cartControllerProvider);
    final grandTotal = ref.watch(cartGrandTotalProvider);
    final completeSaleState = ref.watch(completeSaleControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(completeSaleControllerProvider, (previous, next) {
      final sale = next.value;
      if (sale == null || previous?.value?.id == sale.id) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sale complete — invoice ${sale.provisionalInvoiceNumber}',
            key: const Key('pos_sale_success'),
          ),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Till')),
      body: Column(
        children: [
          Expanded(
            child: products.when(
              data: (items) => items.isEmpty
                  ? const Center(child: Text('No products yet — add one first.'))
                  : ListView.builder(
                      key: const Key('pos_product_list'),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final product = items[index];
                        return ListTile(
                          key: Key('pos_product_${product.id}'),
                          title: Text(product.name),
                          trailing: Text(
                            Money(product.priceMinorUnits).format(),
                          ),
                          onTap: () => ref
                              .read(cartControllerProvider.notifier)
                              .addProduct(product),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Could not load products: $error')),
            ),
          ),
          const Divider(height: 1),
          if (cartLines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Cart is empty — tap a product to add it.', key: Key('pos_cart_empty')),
            )
          else
            ...cartLines.map(
              (line) => ListTile(
                key: Key('pos_cart_line_${line.productId}'),
                title: Text(line.productName),
                subtitle: Text('x${line.quantity}'),
                trailing: Text(Money(line.lineTotalMinorUnits).format()),
                leading: IconButton(
                  key: Key('pos_cart_decrement_${line.productId}'),
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => ref
                      .read(cartControllerProvider.notifier)
                      .decrementProduct(line.productId),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  Money(grandTotal).format(),
                  key: const Key('pos_cart_total'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (completeSaleState.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Could not complete the sale. Try again.',
                key: const Key('pos_sale_error'),
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const Key('pos_complete_sale_button'),
                onPressed: cartLines.isEmpty || completeSaleState.isLoading
                    ? null
                    : () => ref
                        .read(completeSaleControllerProvider.notifier)
                        .completeSale(),
                child: completeSaleState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Complete sale (cash)'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
