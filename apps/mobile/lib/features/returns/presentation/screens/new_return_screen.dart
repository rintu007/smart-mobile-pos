import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../customers/presentation/providers/customer_providers.dart';
import '../../../pos/domain/entities/completed_sale.dart';
import '../../../pos/domain/entities/sale_detail.dart';
import '../../../pos/presentation/providers/pos_providers.dart';
import '../../domain/repositories/return_repository.dart';
import '../providers/return_providers.dart';

/// `/returns/new`, per route-map.md — built Sprint 34 (backlog.md M3 item
/// 4, WF-012). Two ways to locate the original sale, per FR-062/backlog.md's
/// own wording: by invoice number (`SaleRepository.lookupSale`) or via a
/// customer's purchase history — docs/modules/returns/specification.md §1b.
class NewReturnScreen extends ConsumerStatefulWidget {
  const NewReturnScreen({super.key});

  @override
  ConsumerState<NewReturnScreen> createState() => _NewReturnScreenState();
}

class _NewReturnScreenState extends ConsumerState<NewReturnScreen> {
  final _invoiceController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _findingByCustomer = false;
  bool _loading = false;
  String? _lookupError;

  List<Customer> _customerResults = const [];
  Customer? _selectedCustomer;
  List<CompletedSale> _customerHistory = const [];

  SaleDetail? _locatedSale;
  final Map<String, int> _quantities = {};

  @override
  void dispose() {
    _invoiceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _lookupByInvoice() async {
    final value = _invoiceController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _loading = true;
      _lookupError = null;
    });
    final sale = await ref.read(saleRepositoryProvider).lookupSale(provisionalInvoiceNumber: value);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _locatedSale = sale;
      _lookupError = sale == null ? 'No sale found for that invoice number.' : null;
    });
  }

  Future<void> _searchByPhone(String query) async {
    final results = await ref.read(customerRepositoryProvider).searchByPhone(query);
    if (!mounted) return;
    setState(() => _customerResults = results);
  }

  Future<void> _pickCustomer(Customer customer) async {
    setState(() {
      _selectedCustomer = customer;
      _loading = true;
    });
    final history = await ref.read(customerRepositoryProvider).getPurchaseHistory(customer.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _customerHistory = history;
    });
  }

  Future<void> _pickSale(CompletedSale sale) async {
    setState(() {
      _loading = true;
      _lookupError = null;
    });
    final detail = await ref.read(saleRepositoryProvider).fetchRemoteSaleDetail(sale.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _locatedSale = detail;
      _lookupError = detail == null ? 'Could not load that sale.' : null;
    });
  }

  Future<void> _submit() async {
    final sale = _locatedSale;
    if (sale == null) return;
    final lineItems = [
      for (final entry in _quantities.entries)
        if (entry.value > 0)
          ReturnLineItemInput(originalSaleLineItemId: entry.key, quantity: entry.value),
    ];
    if (lineItems.isEmpty) return;

    await ref
        .read(createReturnControllerProvider.notifier)
        .createReturn(originalSaleId: sale.id, lineItems: lineItems);
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createReturnControllerProvider);
    final approveState = ref.watch(approveReturnControllerProvider);

    ref.listen(createReturnControllerProvider, (previous, next) {
      final result = next.value;
      if (result == null || previous?.value?.id == result.id) return;
      if (result.status == 'completed') {
        context.pushReplacement('/returns/${result.id}');
      }
    });

    ref.listen(approveReturnControllerProvider, (previous, next) {
      final result = next.value;
      if (result == null || previous?.value?.id == result.id) return;
      context.pushReplacement('/returns/${result.id}');
    });

    final createdReturn = createState.value;
    final needsApprovalPrompt = createdReturn != null && createdReturn.status == 'pending_approval';

    return Scaffold(
      appBar: AppBar(title: const Text('New return')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (needsApprovalPrompt) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'This return needs approval',
                      key: Key('returns_needs_approval_text'),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Refund total: ${Money(createdReturn.refundTotalMinorUnits).format()}',
                    ),
                    if (approveState.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Could not approve: ${approveState.error}',
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('returns_later_button'),
                            onPressed: () => context.pushReplacement('/returns/${createdReturn.id}'),
                            child: const Text('Later'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            key: const Key('returns_approve_now_button'),
                            onPressed: approveState.isLoading
                                ? null
                                : () => ref
                                      .read(approveReturnControllerProvider.notifier)
                                      .approveReturn(createdReturn.id),
                            child: approveState.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Approve now'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_locatedSale == null) ...[
            Text('Locate the original sale', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: const Key('returns_lookup_field'),
              controller: _invoiceController,
              decoration: const InputDecoration(labelText: 'Invoice number'),
              onSubmitted: (_) => _lookupByInvoice(),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('returns_lookup_button'),
              onPressed: _loading ? null : _lookupByInvoice,
              child: const Text('Look up'),
            ),
            if (_lookupError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _lookupError!,
                  key: const Key('returns_lookup_error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const Divider(height: 32),
            if (!_findingByCustomer)
              OutlinedButton(
                key: const Key('returns_find_by_customer_button'),
                onPressed: () => setState(() => _findingByCustomer = true),
                child: const Text('Find by customer instead'),
              )
            else ...[
              Text('Find by customer phone', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                key: const Key('returns_customer_phone_field'),
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                onChanged: _searchByPhone,
              ),
              const SizedBox(height: 8),
              ..._customerResults.map(
                (customer) => ListTile(
                  key: Key('returns_customer_result_${customer.id}'),
                  title: Text(customer.name ?? customer.phone ?? customer.id),
                  subtitle: customer.phone != null ? Text(customer.phone!) : null,
                  onTap: () => _pickCustomer(customer),
                ),
              ),
              if (_selectedCustomer != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Purchases',
                  key: const Key('returns_customer_history_list'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (_customerHistory.isEmpty && !_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No purchases found', key: Key('returns_customer_history_empty')),
                  )
                else
                  ..._customerHistory.map(
                    (sale) => ListTile(
                      key: Key('returns_customer_sale_${sale.id}'),
                      title: Text(sale.provisionalInvoiceNumber),
                      trailing: Text(Money(sale.grandTotalMinorUnits).format()),
                      onTap: () => _pickSale(sale),
                    ),
                  ),
              ],
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ] else ...[
            Text('Select items to return', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Invoice ${_locatedSale!.provisionalInvoiceNumber}'),
            const SizedBox(height: 12),
            ..._locatedSale!.lines.map((line) {
              final quantity = _quantities[line.id] ?? 0;
              return ListTile(
                key: Key('returns_line_item_${line.id}'),
                title: Text(line.productName ?? line.productId),
                subtitle: Text('Sold ${line.quantity} — ${Money(line.lineTotalMinorUnits).format()}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('returns_line_item_decrement_${line.id}'),
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: quantity <= 0
                          ? null
                          : () => setState(() => _quantities[line.id] = quantity - 1),
                    ),
                    Text('$quantity'),
                    IconButton(
                      key: Key('returns_line_item_increment_${line.id}'),
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: quantity >= line.quantity
                          ? null
                          : () => setState(() => _quantities[line.id] = quantity + 1),
                    ),
                  ],
                ),
              );
            }),
            if (createState.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Could not create the return: ${createState.error}',
                  key: const Key('returns_create_error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('returns_confirm_button'),
              onPressed: createState.isLoading || !_quantities.values.any((q) => q > 0)
                  ? null
                  : _submit,
              child: createState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm return'),
            ),
          ],
        ],
      ),
    );
  }
}
