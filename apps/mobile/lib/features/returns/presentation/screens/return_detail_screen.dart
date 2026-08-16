import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../providers/return_providers.dart';

/// `/returns/:id`, per route-map.md — built Sprint 34 (backlog.md M3 item
/// 4). Approve/reject are shown here whenever `status == 'pending_approval'`
/// — reached either from `NewReturnScreen`'s own inline prompt or from
/// `ReturnApprovalsScreen`'s queue, both landing on this same screen for the
/// actual decision rather than duplicating the decision UI in each place
/// (docs/modules/returns/specification.md §9). A non-Manager/Owner caller's
/// tap on approve/reject simply surfaces the server's own `403`, per §1b.
class ReturnDetailScreen extends ConsumerStatefulWidget {
  const ReturnDetailScreen({super.key, required this.returnId});

  final String returnId;

  @override
  ConsumerState<ReturnDetailScreen> createState() => _ReturnDetailScreenState();
}

class _ReturnDetailScreenState extends ConsumerState<ReturnDetailScreen> {
  final _reasonController = TextEditingController();
  bool _showRejectForm = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(returnDetailProvider(widget.returnId));
    final approveState = ref.watch(approveReturnControllerProvider);
    final rejectState = ref.watch(rejectReturnControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Return')),
      body: detail.when(
        data: (found) {
          if (found == null) {
            return const Center(
              child: Text('Return not found', key: Key('return_detail_not_found')),
            );
          }
          return ListView(
            key: const Key('return_detail_content'),
            padding: const EdgeInsets.all(16),
            children: [
              Text(found.status, style: Theme.of(context).textTheme.titleLarge),
              Text('Refund total: ${Money(found.refundTotalMinorUnits).format()}'),
              const SizedBox(height: 16),
              Text('Line items', style: Theme.of(context).textTheme.titleMedium),
              ...found.lineItems.map(
                (item) => ListTile(
                  key: Key('return_detail_line_${item.originalSaleLineItemId}'),
                  title: Text('Qty ${item.quantity}'),
                  trailing: Text(Money(item.refundAmountMinorUnits).format()),
                ),
              ),
              if (found.status == 'pending_approval') ...[
                const SizedBox(height: 16),
                if (approveState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Could not approve: ${approveState.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (rejectState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Could not reject: ${rejectState.error}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (_showRejectForm) ...[
                  TextField(
                    key: const Key('returns_reject_reason_field'),
                    controller: _reasonController,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    // Rebuilds so the submit button's enabled state (below,
                    // gated on this controller's current text) reflects
                    // every keystroke — a plain `TextEditingController` has
                    // no listener wired otherwise.
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('returns_reject_submit_button'),
                    onPressed: rejectState.isLoading || _reasonController.text.trim().isEmpty
                        ? null
                        : () => ref
                              .read(rejectReturnControllerProvider.notifier)
                              .rejectReturn(found.id, _reasonController.text.trim()),
                    child: const Text('Submit rejection'),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('returns_reject_button'),
                          onPressed: () => setState(() => _showRejectForm = true),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          key: const Key('returns_approve_button'),
                          onPressed: approveState.isLoading
                              ? null
                              : () => ref
                                    .read(approveReturnControllerProvider.notifier)
                                    .approveReturn(found.id),
                          child: approveState.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Could not load return: $error')),
      ),
    );
  }
}
