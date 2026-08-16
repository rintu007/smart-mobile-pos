import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money.dart';
import '../providers/return_providers.dart';

/// `/returns/approvals`, per route-map.md — built Sprint 34 (backlog.md M3
/// item 4, WF-013's queue path). Shown to every signed-in role; the server's
/// own `403 PERMISSION_DENIED` is what actually restricts this to
/// Manager/Owner (docs/modules/returns/specification.md §1b) — a Cashier who
/// reaches this screen sees the same honest error state every other list
/// screen's own `error:` branch already uses, not a hidden/disabled entry
/// point this codebase has no way to gate correctly yet.
///
/// A pure queue — tapping a row navigates to `/returns/:id` for the actual
/// approve/reject decision, reusing `ReturnDetailScreen` rather than
/// duplicating the decision UI here.
class ReturnApprovalsScreen extends ConsumerWidget {
  const ReturnApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvals = ref.watch(approvalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Return approvals')),
      body: approvals.when(
        data: (returns) => returns.isEmpty
            ? const Center(
                child: Text('No returns awaiting approval', key: Key('returns_approvals_empty')),
              )
            : ListView.builder(
                key: const Key('returns_approvals_list'),
                itemCount: returns.length,
                itemBuilder: (context, index) {
                  final item = returns[index];
                  return ListTile(
                    key: Key('returns_approval_row_${item.id}'),
                    title: Text(Money(item.refundTotalMinorUnits).format()),
                    subtitle: Text(item.status),
                    onTap: () => context.push('/returns/${item.id}'),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Could not load approvals: $error')),
      ),
    );
  }
}
