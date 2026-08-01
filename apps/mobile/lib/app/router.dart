import 'package:go_router/go_router.dart';

import 'home_screen.dart';

/// Merges every feature's routes, per mobile-structure.md §4. No feature
/// exists yet (till/catalogue/etc. land in later sprints), so the only route
/// is the app shell's own home screen.
final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
