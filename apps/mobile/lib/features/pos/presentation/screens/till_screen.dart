import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money.dart';
import '../../../catalogue/presentation/providers/category_providers.dart';
import '../../../catalogue/presentation/providers/product_providers.dart';
import '../../../customers/presentation/widgets/customer_picker_sheet.dart';
import '../../../returns/presentation/providers/return_providers.dart';
import '../providers/pos_providers.dart';

/// `/pos`, per route-map.md — backlog.md item 6's till screen. No design-
/// system composition spec exists yet beyond patterns.md's generic list/
/// button states, same reasoning `AddProductScreen` already used.
///
/// Sprint 21 (backlog item 5) adds a search field, category filter chips
/// (FR-036), and a barcode-scan button (FR-034) — all resolved against the
/// local product cache, never the network, per those FRs' own "Fully
/// offline" classification.
class TillScreen extends ConsumerWidget {
  const TillScreen({super.key});

  Future<void> _scanBarcode(BuildContext context, WidgetRef ref) async {
    final barcode = await context.push<String>('/pos/scan');
    if (barcode == null) return;

    final product = await ref.read(productRepositoryProvider).findByBarcode(barcode);
    if (!context.mounted) return;

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No product found for that barcode.', key: Key('pos_barcode_not_found')),
        ),
      );
      return;
    }
    ref.read(cartControllerProvider.notifier).addProduct(product);
  }

  /// FR-050, taken literally — opens `CustomerPickerSheet` over this screen
  /// rather than pushing a route (docs/modules/customers/specification.md
  /// §1a). Attaches the result, if any; a `null` result (dismissed) leaves
  /// the cart's existing attachment untouched.
  Future<void> _pickCustomer(BuildContext context, WidgetRef ref) async {
    final customer = await showCustomerPickerSheet(context);
    if (customer == null || !context.mounted) return;
    ref
        .read(cartControllerProvider.notifier)
        .attachCustomer(
          customerId: customer.id,
          customerName: customer.name,
          customerPhone: customer.phone,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingApprovals = ref.watch(pendingApprovalsCountProvider);
    final products = ref.watch(filteredProductListProvider);
    final categories = ref.watch(categoriesListProvider);
    final selectedCategoryId = ref.watch(posCategoryFilterProvider);
    final cart = ref.watch(cartControllerProvider);
    final cartLines = cart.lines;
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
      appBar: AppBar(
        title: const Text('Till'),
        actions: [
          IconButton(
            key: const Key('pos_scan_barcode_button'),
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan barcode',
            onPressed: () => _scanBarcode(context, ref),
          ),
          // navigation-model.md §2's "Hold" icon — WF-005 step 3 (resume).
          // Always navigates to /pos/hold; that screen itself auto-resumes
          // and pops immediately when exactly one cart is held, per
          // tap-count-audit.md's own 1-tap budget for that case.
          IconButton(
            key: const Key('pos_held_carts_button'),
            icon: const Icon(Icons.pause_circle_outline),
            tooltip: 'Held carts',
            onPressed: () => context.push('/pos/hold'),
          ),
          IconButton(
            key: const Key('pos_sales_history_button'),
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Sales history',
            onPressed: () => context.push('/sales-history'),
          ),
          // Browse/lookup entry point, distinct from the Customer chip
          // below (attach-to-sale) — customers/specification.md §1a's two
          // distinct entry points for two distinct jobs.
          IconButton(
            key: const Key('pos_customers_button'),
            icon: const Icon(Icons.people_outline),
            tooltip: 'Customers',
            onPressed: () => context.push('/customers'),
          ),
          // navigation-model.md §2's "Return" icon — WF-012 (filing).
          IconButton(
            key: const Key('pos_return_button'),
            icon: const Icon(Icons.assignment_return_outlined),
            tooltip: 'New return',
            onPressed: () => context.push('/returns/new'),
          ),
          // The approvals-queue badge, per returns/specification.md §1b's
          // dated correction to returns.md's own "Reports-tab badge"
          // forward reference (no Reports tab exists yet, M4). Shown to
          // every role; a Cashier's own background count fetch 403s and is
          // swallowed inside the repository, so it simply shows no badge —
          // the correct behaviour falling out of the existing
          // error-swallowing convention, not a role check.
          IconButton(
            key: const Key('pos_returns_approvals_button'),
            icon: pendingApprovals.maybeWhen(
              data: (count) => count > 0
                  ? Badge(
                      label: Text('$count'),
                      child: const Icon(Icons.assignment_late_outlined),
                    )
                  : const Icon(Icons.assignment_late_outlined),
              orElse: () => const Icon(Icons.assignment_late_outlined),
            ),
            tooltip: 'Return approvals',
            onPressed: () => context.push('/returns/approvals'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              key: const Key('pos_search_field'),
              decoration: const InputDecoration(
                labelText: 'Search products',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => ref.read(posSearchQueryProvider.notifier).setQuery(value),
            ),
          ),
          categories.when(
            data: (items) => items.isEmpty
                ? const SizedBox.shrink()
                : SizedBox(
                    height: 40,
                    child: ListView(
                      key: const Key('pos_category_filter_chips'),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            key: const Key('pos_category_filter_all'),
                            label: const Text('All'),
                            selected: selectedCategoryId == null,
                            onSelected: (_) =>
                                ref.read(posCategoryFilterProvider.notifier).select(null),
                          ),
                        ),
                        ...items.map(
                          (category) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              key: Key('pos_category_filter_${category.id}'),
                              label: Text(category.name),
                              selected: selectedCategoryId == category.id,
                              onSelected: (_) => ref
                                  .read(posCategoryFilterProvider.notifier)
                                  .select(category.id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (error, stack) => const SizedBox.shrink(),
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                key: const Key('pos_customer_chip'),
                avatar: const Icon(Icons.person_outline, size: 18),
                label: Text(
                  cart.customerId == null
                      ? 'Add customer'
                      : (cart.customerName ?? cart.customerPhone ?? 'Customer'),
                ),
                onPressed: () => _pickCustomer(context, ref),
                onDeleted: cart.customerId == null
                    ? null
                    : () => ref.read(cartControllerProvider.notifier).removeCustomer(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // WF-005 step 1 — hold the active cart, ≤1 tap
                // (tap-count-audit.md).
                Expanded(
                  child: OutlinedButton(
                    key: const Key('pos_hold_button'),
                    onPressed: cartLines.isEmpty
                        ? null
                        : () => ref.read(cartControllerProvider.notifier).hold(),
                    child: const Text('Hold'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: SizedBox(
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
          ),
        ],
      ),
    );
  }
}
