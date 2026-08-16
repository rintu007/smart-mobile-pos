import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money.dart';
import '../../domain/entities/held_sale.dart';
import '../providers/pos_providers.dart';

/// No formatting package dependency yet — matches
/// sales_history_screen.dart's own precedent of plain manual formatting.
String _formatTimestamp(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// `/pos/hold`, per route-map.md — WF-005 step 3, built Sprint 30
/// (backlog.md M2 item 6, Hold/Resume). `ConsumerStatefulWidget`, not
/// `ConsumerWidget` like this feature's other screens — the auto-resume
/// behaviour below is a genuine one-shot side effect on load (per
/// navigation-model.md §2: "auto-resumes immediately if exactly one cart is
/// held"), not something `ref.watch` + build should drive.
class HeldCartsScreen extends ConsumerStatefulWidget {
  const HeldCartsScreen({super.key});

  @override
  ConsumerState<HeldCartsScreen> createState() => _HeldCartsScreenState();
}

class _HeldCartsScreenState extends ConsumerState<HeldCartsScreen> {
  List<HeldSale>? _heldSales;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sales = await ref.read(saleRepositoryProvider).listHeldSales();
    if (!mounted) return;

    // tap-count-audit.md: exactly one held cart auto-resumes with no list
    // shown at all — the common case stays at 1 tap (the app-bar icon
    // itself). Two or more is the documented, accepted exception (2 taps).
    if (sales.length == 1) {
      await _resume(sales.single.id);
      return;
    }
    setState(() => _heldSales = sales);
  }

  Future<void> _resume(String id) async {
    setState(() => _heldSales = null);
    final resumed = await resumeHeldSale(ref, id);
    if (!mounted) return;
    if (resumed) {
      context.pop();
      return;
    }
    // Defensive — the entry no longer exists (e.g. resumed from another
    // device's own local list, not reachable in V1's single-device target,
    // but handled rather than assumed). Reload rather than leave a
    // permanent spinner.
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final heldSales = _heldSales;
    return Scaffold(
      appBar: AppBar(title: const Text('Held carts')),
      body: heldSales == null
          ? const Center(child: CircularProgressIndicator())
          : heldSales.isEmpty
              ? const Center(
                  child: Text('No held carts', key: Key('pos_held_carts_empty')),
                )
              : ListView.builder(
                  key: const Key('pos_held_carts_list'),
                  itemCount: heldSales.length,
                  itemBuilder: (context, index) {
                    final sale = heldSales[index];
                    return ListTile(
                      key: Key('pos_held_cart_${sale.id}'),
                      title: Text(sale.provisionalInvoiceNumber),
                      subtitle: Text(
                        '${sale.itemCount} item(s) — held ${_formatTimestamp(sale.createdAt)}',
                      ),
                      trailing: Text(Money(sale.grandTotalMinorUnits).format()),
                      onTap: () => _resume(sale.id),
                    );
                  },
                ),
    );
  }
}
