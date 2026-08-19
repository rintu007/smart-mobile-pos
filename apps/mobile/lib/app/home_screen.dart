import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/storage/storage_providers.dart';
import '../core/store_context/store_context_providers.dart';
import '../core/sync/sync_providers.dart';
import '../features/authentication/presentation/providers/auth_providers.dart';
import '../features/reports/presentation/providers/reports_providers.dart';
import 'providers.dart';

/// The app shell's own root screen — not a feature, per mobile-structure.md
/// §2 (a "feature" is one of the 11 user-facing folders; this is composition
/// root, same category as router.dart). Exists only to prove the local
/// database opens and is queryable, to offer sign-out (Sprint 06), a way to
/// reach `/catalogue/add` (Sprint 07), to trigger the store-context
/// bootstrap the till screen depends on (Sprint 08), a way to reach `/pos`
/// (Sprint 09), and now `/catalogue/categories`/`/catalogue/units` (Sprint
/// 20) — until a real bottom-nav shell (navigation-model.md) replaces this
/// as the actual home destination.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productCount = ref.watch(productCountProvider);
    final storeContext = ref.watch(storeContextProvider);
    // Fire-and-forget: runs once per app session right after store context
    // resolves (docs/modules/sync-engine/specification.md §1's automatic
    // trigger). Its own AsyncValue is deliberately not read here — a failure
    // is swallowed inside the provider itself, and "Sync now" below is the
    // user-visible half.
    ref.watch(autoSyncOnStartProvider);
    final syncState = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartPOS X'),
        actions: [
          IconButton(
            key: const Key('sign_out_button'),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sprint 54 (docs/13-offline-sync/failure-scenarios.md §3, tier 3) — persistent, not a
            // dismiss-and-forget toast (that document's own wording, taken literally): no close
            // button, shown for as long as the probe reports true. `maybeWhen`'s `orElse` covers
            // both `loading` and `error` as "don't show a warning yet," matching Reports' own
            // fail-closed-on-the-hidden-side precedent — the inverse concern here (a false
            // negative just delays the warning one check, not a security gate) is the deliberately
            // accepted trade-off `isStorageCriticallyLow`'s own docstring states.
            ref
                .watch(isStorageCriticallyLowProvider)
                .maybeWhen(
                  data: (isCritical) => isCritical
                      ? Container(
                          key: const Key('low_storage_warning'),
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.red.shade100,
                          child: const Text(
                            'Storage is almost full. Sales may stop saving reliably — '
                            'free up space now.',
                            style: TextStyle(color: Colors.red),
                          ),
                        )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
            productCount.when(
              data: (count) => Text('Local database ready — $count product(s) cached.'),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Database error: $error'),
            ),
            const SizedBox(height: 12),
            storeContext.when(
              data: (storeId) =>
                  Text('Store context ready.', key: const Key('store_context_ready')),
              loading: () => const CircularProgressIndicator(key: Key('store_context_loading')),
              error: (error, stack) =>
                  Text('Store context error: $error', key: const Key('store_context_error')),
            ),
            const SizedBox(height: 12),
            syncState.when(
              data: (summary) => Text(
                summary == null
                    ? 'Not synced yet this session.'
                    : summary.hadNothingToPush
                    ? 'Synced — nothing queued, ${summary.productsPulled} product(s) pulled.'
                    : 'Synced — ${summary.accepted} pushed, ${summary.pending} pending, '
                          '${summary.rejected} rejected, ${summary.productsPulled} product(s) pulled.',
                key: const Key('sync_status'),
              ),
              loading: () => const CircularProgressIndicator(key: Key('sync_loading')),
              error: (error, stack) => Text('Sync failed: $error', key: const Key('sync_error')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('sync_now_button'),
              onPressed: () => ref.read(syncControllerProvider.notifier).syncNow(),
              child: const Text('Sync now'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('go_to_categories_button'),
              onPressed: () => context.push('/catalogue/categories'),
              child: const Text('Categories'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('go_to_units_button'),
              onPressed: () => context.push('/catalogue/units'),
              child: const Text('Units'),
            ),
            // Sprint 37 (backlog.md M4 item 2) — hidden entirely, not merely
            // disabled, for a Cashier (or while the probe is still loading/
            // failed): docs/modules/reports/specification.md §1's "visibility,
            // not an error state" design decision, since no network call at
            // report-view time exists to surface a 403 the way every other
            // role-gated screen in this codebase does.
            ref
                .watch(canViewReportsProvider)
                .maybeWhen(
                  data: (canView) => canView
                      ? Column(
                          children: [
                            const SizedBox(height: 8),
                            OutlinedButton(
                              key: const Key('go_to_reports_button'),
                              onPressed: () => context.push('/reports'),
                              child: const Text('Reports'),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
            // Sprint 38 (backlog.md M4 item 3) — always visible (Pattern B,
            // not Reports' Pattern A): a Cashier/Manager reaching this
            // screen sees the same role-shaped `GET /settings` response and
            // the same honest `403` on `PATCH` as everyone else, per
            // settings_screen.dart's own docstring.
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('go_to_settings_button'),
              onPressed: () => context.push('/settings'),
              child: const Text('Settings'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            key: const Key('go_to_till_button'),
            onPressed: () => context.push('/pos'),
            child: const Text('Go to till'),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_product_fab'),
        tooltip: 'Add product',
        onPressed: () => context.push('/catalogue/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
