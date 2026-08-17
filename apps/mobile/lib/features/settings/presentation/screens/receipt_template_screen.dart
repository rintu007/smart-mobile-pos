import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/shop_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../providers/settings_providers.dart';

/// `/settings/receipt-template`, per route-map.md (M4 item 4) — the only
/// customisable receipt content, per
/// [receipt-design.md §2](../../../../../../docs/10-design-system/receipt-design.md#2-layout--common-structure-two-widths)'s
/// own "a configurable one-line thank-you message, never hard-coded" line.
/// Every other zone (shop name, invoice number/date, line items, totals) is
/// mandatory and simply isn't a key `PATCH /settings`'s `receipt_template_config`
/// schema accepts at all — FR-078's "cannot be disabled" is satisfied by
/// construction, not by a runtime check, since there's no key to disable it
/// with. Same Pattern B shape `/settings` itself uses: reachable by every
/// role, the server's own `403` on a non-Owner `PATCH` is what actually
/// restricts editing (settings/specification.md §1/§9).
class ReceiptTemplateScreen extends ConsumerWidget {
  const ReceiptTemplateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt template')),
      body: settings.when(
        data: (data) => _ReceiptTemplateForm(
          key: ValueKey(data.updatedAt.toIso8601String()),
          initial: data,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            const Center(child: Text('Could not load settings. Try again.')),
      ),
    );
  }
}

class _ReceiptTemplateForm extends ConsumerStatefulWidget {
  const _ReceiptTemplateForm({super.key, required this.initial});

  final ShopSettings initial;

  @override
  ConsumerState<_ReceiptTemplateForm> createState() => _ReceiptTemplateFormState();
}

class _ReceiptTemplateFormState extends ConsumerState<_ReceiptTemplateForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _footerController;

  @override
  void initState() {
    super.initState();
    _footerController = TextEditingController(
      text: widget.initial.footerMessage ?? 'Thank you, visit again!',
    );
  }

  @override
  void dispose() {
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // A true partial update — only `footerMessage` is sent, per
    // `SettingsRepository.updateSettings`'s own doc comment; every other
    // field is left untouched server-side.
    await ref
        .read(saveSettingsControllerProvider.notifier)
        .save(base: widget.initial, footerMessage: _footerController.text.trim());
  }

  String _errorMessage(Object? error) {
    if (error is SettingsPermissionDeniedException) {
      return 'Only the Owner can change the receipt template.';
    }
    if (error is SettingsConflictException) {
      return 'Someone else changed these settings. Refresh and try again.';
    }
    return 'Could not save the receipt template. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(saveSettingsControllerProvider);
    final isSaving = saveState.isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Every other receipt field (shop name, invoice number, date, '
                'line items, totals) is mandatory and cannot be changed here.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('receipt_template_footer_field'),
                controller: _footerController,
                enabled: !isSaving,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Footer message',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a footer message.' : null,
              ),
              if (saveState.hasError) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage(saveState.error),
                        key: const Key('receipt_template_error_text'),
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
                  key: const Key('receipt_template_save_button'),
                  onPressed: isSaving ? null : _submit,
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
