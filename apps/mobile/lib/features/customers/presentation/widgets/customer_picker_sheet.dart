import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/customer.dart';
import '../providers/customer_providers.dart';

/// FR-050's "captured inline during checkout without leaving the sale
/// screen," taken literally (docs/modules/customers/specification.md §1a) —
/// a modal bottom sheet over the till screen, not a route push. Returns the
/// attached [Customer] via `Navigator.pop`, or `null` if dismissed without a
/// selection. Local, transient search state (not a shared provider) —
/// deliberately isolated from `CustomersScreen`'s own search query so
/// opening the sheet never leaves stray state behind for the standalone
/// browse screen to inherit.
Future<Customer?> showCustomerPickerSheet(BuildContext context) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const CustomerPickerSheet(),
  );
}

class CustomerPickerSheet extends ConsumerStatefulWidget {
  const CustomerPickerSheet({super.key});

  @override
  ConsumerState<CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<CustomerPickerSheet> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  List<Customer> _results = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final results = await ref.read(customerRepositoryProvider).searchByPhone(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _createAndAttach() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    await ref
        .read(createCustomerControllerProvider.notifier)
        .createCustomer(name: name.isEmpty ? null : name, phone: phone.isEmpty ? null : phone);
    final created = ref.read(createCustomerControllerProvider).value;
    if (created != null && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createCustomerControllerProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Attach a customer', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                key: const Key('pos_customer_search'),
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search by phone',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _search,
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_results.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final customer = _results[index];
                      return ListTile(
                        key: Key('pos_customer_result_${customer.id}'),
                        title: Text(customer.name ?? customer.phone ?? customer.id),
                        subtitle: customer.name != null && customer.phone != null
                            ? Text(customer.phone!)
                            : null,
                        onTap: () => Navigator.of(context).pop(customer),
                      );
                    },
                  ),
                ),
              const Divider(height: 32),
              Text('Or add a new customer', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                key: const Key('pos_customer_new_name'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name (optional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('pos_customer_new_phone'),
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone (optional)'),
                keyboardType: TextInputType.phone,
              ),
              if (createState.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Could not create customer: ${createState.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('pos_customer_create_button'),
                onPressed: createState.isLoading ? null : _createAndAttach,
                child: createState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create & attach'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
