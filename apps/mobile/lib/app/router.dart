import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/session.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import '../features/catalogue/presentation/screens/add_product_screen.dart';
import '../features/catalogue/presentation/screens/categories_screen.dart';
import '../features/catalogue/presentation/screens/units_screen.dart';
import '../features/pos/presentation/screens/barcode_scan_screen.dart';
import '../features/pos/presentation/screens/till_screen.dart';
import '../features/sales_history/presentation/screens/sale_detail_screen.dart';
import '../features/sales_history/presentation/screens/sales_history_screen.dart';
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
      GoRoute(
        path: '/catalogue/add',
        builder: (context, state) => const AddProductScreen(),
      ),
      GoRoute(
        path: '/catalogue/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/catalogue/units',
        builder: (context, state) => const UnitsScreen(),
      ),
      GoRoute(path: '/pos', builder: (context, state) => const TillScreen()),
      GoRoute(
        path: '/pos/scan',
        builder: (context, state) => const BarcodeScanScreen(),
      ),
      GoRoute(
        path: '/sales-history',
        builder: (context, state) => const SalesHistoryScreen(),
      ),
      GoRoute(
        path: '/sales-history/:id',
        builder: (context, state) =>
            SaleDetailScreen(saleId: state.pathParameters['id']!),
      ),
    ],
  );
});
