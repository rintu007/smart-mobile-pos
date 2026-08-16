import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/customer_providers.dart';

/// `/customers/:id/edit`, per route-map.md — built Sprint 35 (backlog.md M3 item 5, §1c). This
/// sprint's first mobile customer-edit UI at all. Saving writes locally and enqueues
/// `customer.update` — no blocking network call, always succeeds locally regardless of
/// connectivity (docs/modules/customers/specification.md §1c/§7).
class CustomerEditScreen extends ConsumerStatefulWidget {
  const CustomerEditScreen({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends ConsumerState<CustomerEditScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _initialised = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    await ref
        .read(updateCustomerControllerProvider.notifier)
        .updateCustomer(
          id: widget.customerId,
          name: name.isEmpty ? null : name,
          phone: phone.isEmpty ? null : phone,
        );
    final saved = ref.read(updateCustomerControllerProvider);
    if (!saved.hasError && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = ref.watch(customerByIdProvider(widget.customerId));
    final saveState = ref.watch(updateCustomerControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit customer')),
      body: customer.when(
        data: (found) {
          if (found == null) {
            return const Center(
              child: Text('Customer not found', key: Key('customer_edit_not_found')),
            );
          }
          if (!_initialised) {
            _nameController.text = found.name ?? '';
            _phoneController.text = found.phone ?? '';
            _initialised = true;
          }
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('customer_edit_name_field'),
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('customer_edit_phone_field'),
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                ),
                if (saveState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Could not save: ${saveState.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('customer_edit_save_button'),
                  onPressed: saveState.isLoading ? null : _save,
                  child: saveState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Could not load customer: $error')),
      ),
    );
  }
}
