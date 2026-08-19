import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/providers.dart';
import '../../../../core/database/device_identity_repository.dart';
import '../../../../core/network/device_registration_api.dart';
import '../../../../core/store_context/store_context_providers.dart';
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
    state = await AsyncValue.guard(() async {
      await ref
          .read(authRepositoryProvider)
          .signInWithPassword(email: email, password: password);

      // Sprint 56 (docs/11-api/authentication.md §2) — "every subsequent API request is rejected
      // until this step has completed once per install." `main.dart`'s own bootstrap only
      // registers on launch if a session *already* existed; a fresh interactive sign-in has none
      // at that point, so it registers here instead, right after the sign-in call itself succeeds.
      // Best-effort, matching `main.dart`'s own swallowed-failure pattern for the same call: a
      // transient failure here must not surface as "sign-in failed" when the credentials were
      // actually valid — the very next authenticated call would surface `DEVICE_REVOKED` anyway if
      // registration genuinely never succeeds.
      try {
        final deviceIdentity = await ensureDeviceIdentity(ref.read(appDatabaseProvider));
        await registerDevice(ref.read(apiClientProvider), deviceIdentity.clientDeviceId);
      } catch (_) {
        // Deliberately swallowed — see docstring above.
      }
    });
  }
}

final signInControllerProvider =
    AsyncNotifierProvider<SignInController, void>(SignInController.new);
