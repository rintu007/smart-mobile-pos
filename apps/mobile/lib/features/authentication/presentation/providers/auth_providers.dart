import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';

/// Manual (non-code-generated) Riverpod syntax — `riverpod_generator` is not
/// a dependency yet (version conflict with `drift_dev`, per Sprint 03's
/// findings), so every provider in this project is written by hand until
/// the ecosystem catches up.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(Supabase.instance.client);
});

/// Drives the login screen's submit button: `AsyncLoading` while the
/// Supabase call is in flight, `AsyncError` holding an `AuthFailure` on
/// failure, `AsyncData(null)` on success. The screen itself never talks to
/// `AuthRepository` directly.
class SignInController extends AsyncNotifier<void> {
  @override
  // Deliberately not `async` — an `async` body always resolves via a
  // microtask, which would make the controller start in `AsyncLoading` for
  // one frame even though no sign-in attempt has happened yet. Returning
  // synchronously keeps the initial state `AsyncData(null)`.
  FutureOr<void> build() {}

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithPassword(email: email, password: password),
    );
  }
}

final signInControllerProvider =
    AsyncNotifierProvider<SignInController, void>(SignInController.new);
