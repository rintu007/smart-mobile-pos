import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/presentation/providers/auth_providers.dart';
import 'providers.dart';

/// The app shell's own root screen — not a feature, per mobile-structure.md
/// §2 (a "feature" is one of the 11 user-facing folders; this is composition
/// root, same category as router.dart). Exists only to prove the local
/// database opens and is queryable, to offer sign-out (Sprint 06), and now
/// (Sprint 07) a way to reach `/catalogue/add`, until the first real feature
/// (till/catalogue's own product list) replaces it as the actual home
/// destination.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productCount = ref.watch(productCountProvider);

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
        child: productCount.when(
          data: (count) => Text('Local database ready — $count product(s) cached.'),
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => Text('Database error: $error'),
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
