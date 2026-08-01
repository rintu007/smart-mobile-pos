import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// The app shell's own root screen — not a feature, per mobile-structure.md
/// §2 (a "feature" is one of the 11 user-facing folders; this is composition
/// root, same category as router.dart). Exists only to prove the local
/// database opens and is queryable until the first real feature (Sprint 03+)
/// replaces it as the actual home destination.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productCount = ref.watch(productCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('SmartPOS X')),
      body: Center(
        child: productCount.when(
          data: (count) => Text('Local database ready — $count product(s) cached.'),
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => Text('Database error: $error'),
        ),
      ),
    );
  }
}
