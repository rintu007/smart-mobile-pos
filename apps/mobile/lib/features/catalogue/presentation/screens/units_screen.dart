import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/unit_providers.dart';

/// `/catalogue/units`, per route-map.md (Manager+) — same shape as
/// `CategoriesScreen`.
class UnitsScreen extends ConsumerWidget {
  const UnitsScreen({super.key});

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final symbolController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var allowsFractional = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('New unit'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('unit_name_field'),
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Enter a unit name.' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('unit_symbol_field'),
                  controller: symbolController,
                  decoration: const InputDecoration(labelText: 'Symbol'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Enter a symbol.' : null,
                ),
                CheckboxListTile(
                  key: const Key('unit_allows_fractional_checkbox'),
                  title: const Text('Allows fractional quantities'),
                  value: allowsFractional,
                  onChanged: (value) => setDialogState(() => allowsFractional = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('unit_dialog_save_button'),
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await ref
          .read(createUnitControllerProvider.notifier)
          .createUnit(
            name: nameController.text.trim(),
            symbol: symbolController.text.trim(),
            allowsFractional: allowsFractional,
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsListProvider);
    final createState = ref.watch(createUnitControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Units')),
      body: units.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('No units yet', key: Key('units_empty')))
            : ListView.builder(
                key: const Key('units_list'),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final unit = items[index];
                  return ListTile(
                    key: Key('unit_${unit.id}'),
                    title: Text(unit.name),
                    subtitle: Text(unit.symbol),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => const Center(child: Text('Could not load units. Try again.')),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_unit_fab'),
        tooltip: 'Add unit',
        onPressed: createState.isLoading ? null : () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
