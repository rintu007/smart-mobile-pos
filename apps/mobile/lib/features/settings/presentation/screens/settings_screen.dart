import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../domain/entities/shop_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../providers/settings_providers.dart';

/// `/settings`, per route-map.md (M4 item 3) — reachable by every signed-in
/// role (Pattern B, `return_approvals_screen.dart`'s own precedent): a
/// Cashier/Manager sees the same fields their `GET /settings` response
/// already includes (the two auto-approval thresholds simply aren't in the
/// response for a Cashier, so they never render), and a `PATCH` attempt
/// from anyone but the Owner gets the server's own honest `403` surfaced as
/// a plain error message rather than a hidden/disabled entry point — the
/// same reasoning that screen's own docstring already gives, and the
/// opposite choice from Reports' hide-entirely pattern, named explicitly in
/// docs/modules/settings/specification.md §9 since this is the first
/// screen in this codebase to face this exact decision a second time.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings.when(
        data: (data) => _SettingsForm(
          // Forces a fresh `State` (fresh controllers) whenever the loaded
          // row actually changes — after a successful save or a discarded
          // conflict, not on every rebuild.
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

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({super.key, required this.initial});

  final ShopSettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late String _taxMode;
  late String _pricingMode;
  late String _roundingRule;
  late final TextEditingController _taxRateController;
  late final TextEditingController _currencyController;
  late final TextEditingController _lowStockController;
  TextEditingController? _discountThresholdController;
  TextEditingController? _returnThresholdController;
  String? _crossFieldError;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    _taxMode = s.taxMode;
    _pricingMode = s.pricingMode;
    _roundingRule = s.roundingRule;
    _taxRateController = TextEditingController(
      text: (s.taxRateBasisPoints / 100).toStringAsFixed(2),
    );
    _currencyController = TextEditingController(text: s.currencyCode);
    _lowStockController = TextEditingController(
      text: s.lowStockThresholdQuantity.toString(),
    );
    if (s.discountAutoApprovalThresholdMinorUnits != null) {
      _discountThresholdController = TextEditingController(
        text: (s.discountAutoApprovalThresholdMinorUnits! / 100).toStringAsFixed(2),
      );
    }
    if (s.returnAutoApprovalThresholdMinorUnits != null) {
      _returnThresholdController = TextEditingController(
        text: (s.returnAutoApprovalThresholdMinorUnits! / 100).toStringAsFixed(2),
      );
    }
  }

  @override
  void dispose() {
    _taxRateController.dispose();
    _currencyController.dispose();
    _lowStockController.dispose();
    _discountThresholdController?.dispose();
    _returnThresholdController?.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _crossFieldError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final taxRateBasisPoints = (double.parse(_taxRateController.text.trim()) * 100).round();
    // DR-009, checked client-side too so a doomed request never round-trips
    // to the server just to learn what settings/specification.md §5 already
    // states plainly: composition/unregistered shops carry no tax rate.
    if (_taxMode != 'standard' && taxRateBasisPoints != 0) {
      setState(
        () => _crossFieldError = 'Tax rate must be 0 unless tax mode is Standard.',
      );
      return;
    }

    await ref
        .read(saveSettingsControllerProvider.notifier)
        .save(
          base: widget.initial,
          taxMode: _taxMode,
          taxRateBasisPoints: taxRateBasisPoints,
          pricingMode: _pricingMode,
          roundingRule: _roundingRule,
          currencyCode: _currencyController.text.trim(),
          lowStockThresholdQuantity: int.parse(_lowStockController.text.trim()),
          discountAutoApprovalThresholdMinorUnits: _discountThresholdController == null
              ? null
              : Money.tryParseMajorUnits(_discountThresholdController!.text)?.minorUnits,
          returnAutoApprovalThresholdMinorUnits: _returnThresholdController == null
              ? null
              : Money.tryParseMajorUnits(_returnThresholdController!.text)?.minorUnits,
        );
  }

  String _errorMessage(Object? error) {
    if (error is SettingsPermissionDeniedException) {
      return 'Only the Owner can change settings.';
    }
    if (error is SettingsConflictException) {
      return 'Someone else changed these settings. Refresh and try again.';
    }
    return 'Could not save settings. Try again.';
  }

  @override
  Widget build(BuildContext context) {
    final saveState = ref.watch(saveSettingsControllerProvider);
    final isSaving = saveState.isLoading;
    final colorScheme = Theme.of(context).colorScheme;
    final errorText =
        _crossFieldError ?? (saveState.hasError ? _errorMessage(saveState.error) : null);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('settings_tax_mode_field'),
                initialValue: _taxMode,
                decoration: const InputDecoration(
                  labelText: 'Tax mode',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'standard', child: Text('Standard')),
                  DropdownMenuItem(value: 'composition', child: Text('Composition')),
                  DropdownMenuItem(value: 'unregistered', child: Text('Unregistered')),
                ],
                onChanged: isSaving ? null : (value) => setState(() => _taxMode = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('settings_tax_rate_field'),
                controller: _taxRateController,
                enabled: !isSaving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Tax rate (%)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final rate = double.tryParse((value ?? '').trim());
                  if (rate == null || rate < 0 || rate > 100) {
                    return 'Enter a rate between 0 and 100.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('settings_pricing_mode_field'),
                initialValue: _pricingMode,
                decoration: const InputDecoration(
                  labelText: 'Pricing mode',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'inclusive', child: Text('Tax-inclusive pricing')),
                  DropdownMenuItem(value: 'exclusive', child: Text('Tax-exclusive pricing')),
                ],
                onChanged: isSaving ? null : (value) => setState(() => _pricingMode = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('settings_rounding_rule_field'),
                initialValue: _roundingRule,
                decoration: const InputDecoration(
                  labelText: 'Rounding rule',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'round_half_up', child: Text('Round half up')),
                  DropdownMenuItem(value: 'round_half_even', child: Text('Round half to even')),
                ],
                onChanged: isSaving ? null : (value) => setState(() => _roundingRule = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('settings_currency_field'),
                controller: _currencyController,
                enabled: !isSaving,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Currency code',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value ?? '').trim().length == 3 ? null : 'Enter a 3-letter currency code.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('settings_low_stock_threshold_field'),
                controller: _lowStockController,
                enabled: !isSaving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Low stock threshold (units)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final quantity = int.tryParse((value ?? '').trim());
                  if (quantity == null || quantity < 0) {
                    return 'Enter a whole number, 0 or more.';
                  }
                  return null;
                },
              ),
              if (_discountThresholdController != null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('settings_discount_threshold_field'),
                  controller: _discountThresholdController,
                  enabled: !isSaving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Discount auto-approval threshold',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => Money.tryParseMajorUnits(value ?? '') == null
                      ? 'Enter a valid, non-negative amount.'
                      : null,
                ),
              ],
              if (_returnThresholdController != null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('settings_return_threshold_field'),
                  controller: _returnThresholdController,
                  enabled: !isSaving,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Return auto-approval threshold',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => Money.tryParseMajorUnits(value ?? '') == null
                      ? 'Enter a valid, non-negative amount.'
                      : null,
                ),
              ],
              if (errorText != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.error_outline, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorText,
                        key: const Key('settings_error_text'),
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
                  key: const Key('settings_save_button'),
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
