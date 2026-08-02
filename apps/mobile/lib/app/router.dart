import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/session.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import 'home_screen.dart';

/// Bridges Supabase's auth-state stream to `GoRouter`'s `refreshListenable`,
/// so a sign-in/sign-out re-runs the redirect guard below without any
/// screen manually navigating on success — per mobile-structure.md, the
/// router is the one place that reacts to session state on every route.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Merges every feature's routes, per mobile-structure.md §4.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshStream = GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  );
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    refreshListenable: refreshStream,
    initialLocation: '/',
    redirect: (context, state) {
      final signedIn = currentSession() != null;
      final onLoginRoute = state.matchedLocation == '/auth/login';

      if (!signedIn && !onLoginRoute) return '/auth/login';
      if (signedIn && onLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
});
