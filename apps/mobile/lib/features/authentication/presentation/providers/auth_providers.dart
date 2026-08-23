import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/providers.dart';
import '../../../../core/database/device_identity_repository.dart';
import '../../../../core/network/device_registration_api.dart';
import '../../../../core/store_context/store_context_providers.dart';
import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/entities/auth_failure.dart';
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

  // Sprint 64 (docs/11-api/rate-limiting.md's Auth-class finding, Sprint 45) — client-side
  // defense-in-depth only, not a substitute for server-side protection. Sign-in itself is a direct
  // client call to Supabase Auth, never reaching an `apps/web` Route Handler this codebase's own
  // rate limiter could intercept — that finding still holds, unchanged. What was actually missing,
  // found re-examining it: nothing on the client slowed a rapid sequence of failed attempts either,
  // despite that being ordinary, safe engineering work independent of any Supabase setting. This
  // only throttles the *same running app instance* — restarting the app resets it, an accepted,
  // named limitation (matching the countermeasure's own honest scope), not an oversight. The first
  // 3 failures are always free, so a Cashier who mistypes a password twice is never delayed.
  static const _freeAttempts = 3;
  static const _baseCooldown = Duration(seconds: 5);
  static const _maxCooldown = Duration(seconds: 60);

  int _consecutiveFailures = 0;
  DateTime? _cooldownUntil;

  Future<void> signIn({required String email, required String password}) async {
    final cooldownUntil = _cooldownUntil;
    if (cooldownUntil != null && DateTime.now().isBefore(cooldownUntil)) {
      final remainingSeconds = cooldownUntil.difference(DateTime.now()).inSeconds + 1;
      state = AsyncError(
        AuthFailure('Too many attempts. Try again in ${remainingSeconds}s.'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await ref
            .read(authRepositoryProvider)
            .signInWithPassword(email: email, password: password);
      } catch (_) {
        _registerFailedAttempt();
        rethrow;
      }
      _consecutiveFailures = 0;
      _cooldownUntil = null;

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

  void _registerFailedAttempt() {
    _consecutiveFailures++;
    if (_consecutiveFailures <= _freeAttempts) return;
    final exponent = _consecutiveFailures - _freeAttempts - 1;
    final cooldown = _baseCooldown * (1 << exponent);
    _cooldownUntil = DateTime.now().add(cooldown > _maxCooldown ? _maxCooldown : cooldown);
  }
}

final signInControllerProvider =
    AsyncNotifierProvider<SignInController, void>(SignInController.new);
