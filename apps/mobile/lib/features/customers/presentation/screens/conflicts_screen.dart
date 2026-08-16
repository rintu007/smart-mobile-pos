import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/customer_field_conflict.dart';
import '../providers/customer_providers.dart';

/// `/customers/conflicts`, per route-map.md — built Sprint 35 (backlog.md M3 item 5, §1c,
/// M3's own hard exit criterion). Shown to every signed-in role; the server's own
/// `403 PERMISSION_DENIED` is what actually restricts this to Manager/Owner
/// (docs/modules/customers/specification.md §1c) — a Cashier who reaches this screen sees the same
/// honest error state every other list screen's own `error:` branch already uses.
class ConflictsScreen extends ConsumerStatefulWidget {
  const ConflictsScreen({super.key});

  @override
  ConsumerState<ConflictsScreen> createState() => _ConflictsScreenState();
}

class _ConflictsScreenState extends ConsumerState<ConflictsScreen> {
  String? _expandedId;

  Future<void> _resolve(CustomerFieldConflict conflict, String? resolvedValue) async {
    await ref
        .read(resolveConflictControllerProvider.notifier)
        .resolveConflict(conflictId: conflict.id, resolvedValue: resolvedValue);
    if (!mounted) return;
    setState(() => _expandedId = null);
    ref.invalidate(conflictsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = ref.watch(conflictsProvider);
    final resolveState = ref.watch(resolveConflictControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Field conflicts')),
      body: conflicts.when(
        data: (items) => items.isEmpty
            ? const Center(
                child: Text('No conflicts to review', key: Key('customer_conflicts_empty')),
              )
            : ListView.builder(
                key: const Key('customer_conflicts_list'),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final conflict = items[index];
                  final expanded = _expandedId == conflict.id;
                  return Column(
                    children: [
                      ListTile(
                        key: Key('customer_conflict_row_${conflict.id}'),
                        title: Text('${conflict.customerName ?? 'A customer'}\'s ${conflict.field}'),
                        subtitle: const Text('Changed by two people at the same time'),
                        onTap: () => setState(() => _expandedId = expanded ? null : conflict.id),
                      ),
                      if (expanded)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "${conflict.currentSetByName} set it to ${conflict.currentValue ?? '(nothing)'}. "
                                "${conflict.attemptedSetByName} set it to ${conflict.attemptedValue ?? '(nothing)'}. "
                                'Which is correct?',
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                key: Key('customer_conflict_choice_current_${conflict.id}'),
                                onPressed: resolveState.isLoading
                                    ? null
                                    : () => _resolve(conflict, conflict.currentValue),
                                child: Text('${conflict.currentValue ?? '(nothing)'} (${conflict.currentSetByName})'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                key: Key('customer_conflict_choice_attempted_${conflict.id}'),
                                onPressed: resolveState.isLoading
                                    ? null
                                    : () => _resolve(conflict, conflict.attemptedValue),
                                child: Text(
                                  '${conflict.attemptedValue ?? '(nothing)'} (${conflict.attemptedSetByName})',
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                    ],
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Could not load conflicts: $error')),
      ),
    );
  }
}
