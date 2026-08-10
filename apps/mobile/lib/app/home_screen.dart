import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/store_context/store_context_providers.dart';
import '../features/authentication/presentation/providers/auth_providers.dart';
import 'providers.dart';

/// The app shell's own root screen — not a feature, per mobile-structure.md
/// §2 (a "feature" is one of the 11 user-facing folders; this is composition
/// root, same category as router.dart). Exists only to prove the local
/// database opens and is queryable, to offer sign-out (Sprint 06), a way to
/// reach `/catalogue/add` (Sprint 07), to trigger the store-context
/// bootstrap the till screen depends on (Sprint 08), and now a way to reach
/// `/pos` (Sprint 09) — until a real bottom-nav shell
/// (navigation-model.md) replaces this as the actual home destination.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productCount = ref.watch(productCountProvider);
    final storeContext = ref.watch(storeContextProvider);

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
