import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/category_providers.dart';

/// `/catalogue/categories`, per route-map.md (Manager+). No dedicated
/// design-system composition spec exists for this screen, same reasoning
/// `AddProductScreen` already used — follows components.md's generic
/// list/button/text-field states. Creation is online-only — see
/// `CategoryRepository.createCategory`'s docstring for why.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: const Key('category_name_field'),
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Enter a category name.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('category_dialog_save_button'),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(createCategoryControllerProvider.notifier)
          .createCategory(name: nameController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesListProvider);
    final createState = ref.watch(createCategoryControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: categories.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('No categories yet', key: Key('categories_empty')))
            : ListView.builder(
                key: const Key('categories_list'),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final category = items[index];
                  return ListTile(
                    key: Key('category_${category.id}'),
                    title: Text(category.name),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        // Plain-language, no raw error/stack trace — state-presentation.md §3.
        error: (error, stack) =>
            const Center(child: Text('Could not load categories. Try again.')),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_category_fab'),
        tooltip: 'Add category',
        onPressed: createState.isLoading ? null : () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
