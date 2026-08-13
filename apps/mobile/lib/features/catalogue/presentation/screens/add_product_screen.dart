import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../providers/category_providers.dart';
import '../providers/product_providers.dart';
import '../providers/unit_providers.dart';

/// `/catalogue/add`, per route-map.md (added this sprint — see its own
/// changelog). No dedicated design-system spec for this screen exists yet
/// (only the till screen is composed in patterns.md), so this follows
/// components.md §1/§2's generic button/text-field states, same reasoning
/// `LoginScreen` already used.
///
/// Sprint 20 (backlog item 4) adds required category/unit selection — a
/// UI-level requirement (`ProductRepository.createProduct`'s own docstring),
/// not a server one.
class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String? _categoryId;
  String? _unitId;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final priceMinorUnits =
        Money.tryParseMajorUnits(_priceController.text)!.minorUnits;
    await ref
        .read(createProductControllerProvider.notifier)
        .createProduct(
          name: _nameController.text.trim(),
          priceMinorUnits: priceMinorUnits,
          categoryId: _categoryId!,
          unitId: _unitId!,
        );
    if (!mounted) return;
    final state = ref.read(createProductControllerProvider);
    if (!state.hasError && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final createState = ref.watch(createProductControllerProvider);
    final isLoading = createState.isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    final categories = ref.watch(categoriesListProvider);
    final units = ref.watch(unitsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add product')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('add_product_name_field'),
                      controller: _nameController,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a product name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('add_product_price_field'),
                      controller: _priceController,
                      enabled: !isLoading,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null ||
                            Money.tryParseMajorUnits(value) == null) {
                          return 'Enter a valid, non-negative price.';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
                    categories.when(
                      data: (items) => DropdownButtonFormField<String>(
                        key: const Key('add_product_category_field'),
                        initialValue: _categoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: items
                            .map(
                              (category) => DropdownMenuItem(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            )
                            .toList(),
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() => _categoryId = value),
                        validator: (value) =>
                            value == null ? 'Select a category.' : null,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stack) =>
                          const Text('Could not load categories.'),
                    ),
                    const SizedBox(height: 16),
                    units.when(
                      data: (items) => DropdownButtonFormField<String>(
                        key: const Key('add_product_unit_field'),
                        initialValue: _unitId,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                        items: items
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit.id,
                                child: Text('${unit.name} (${unit.symbol})'),
                              ),
                            )
                            .toList(),
                        onChanged: isLoading
                            ? null
                            : (value) => setState(() => _unitId = value),
                        validator: (value) =>
                            value == null ? 'Select a unit.' : null,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stack) => const Text('Could not load units.'),
                    ),
                    if (createState.hasError) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Could not save the product. Try again.',
                              key: const Key('add_product_error_text'),
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        key: const Key('add_product_submit_button'),
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
