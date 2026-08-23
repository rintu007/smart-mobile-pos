import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/authentication/domain/entities/auth_failure.dart';
import 'package:mobile/features/authentication/domain/repositories/auth_repository.dart';
import 'package:mobile/features/authentication/presentation/providers/auth_providers.dart';

/// A fake, not a mock — this codebase's established convention (e.g.
/// login_screen_test.dart's own `_FakeAuthRepository`), reused here to test
/// `SignInController`'s attempt-throttling logic directly, without a widget
/// tree.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.alwaysFails = false});

  final bool alwaysFails;
  int signInCalls = 0;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (alwaysFails) {
      throw const AuthFailure('Invalid login credentials');
    }
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  // Sprint 64 (docs/11-api/rate-limiting.md's Auth-class finding, Sprint 45) — client-side
  // defense-in-depth: the server can never rate-limit the sign-in request itself (it never reaches
  // an apps/web Route Handler), so this throttling lives entirely in SignInController. Tested
  // directly via ProviderContainer, not a widget tree, since none of this logic touches the UI.
  test('the first 3 failures are free — no cooldown, the repository is actually called each time', () async {
    final repository = _FakeAuthRepository(alwaysFails: true);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(signInControllerProvider.notifier);

    for (var i = 0; i < 3; i++) {
      await controller.signIn(email: 'owner@example.com', password: 'wrong');
      final state = container.read(signInControllerProvider);
      expect(state.hasError, isTrue);
      expect((state.error! as AuthFailure).message, 'Invalid login credentials');
    }

    expect(repository.signInCalls, 3);
  });

  test('the 4th consecutive failure triggers a cooldown — the next attempt is blocked client-side, the repository is not called again', () async {
    final repository = _FakeAuthRepository(alwaysFails: true);
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(signInControllerProvider.notifier);

    for (var i = 0; i < 4; i++) {
      await controller.signIn(email: 'owner@example.com', password: 'wrong');
    }
    expect(repository.signInCalls, 4);

    // A 5th attempt, immediately — should be blocked by the cooldown before ever reaching the
    // repository, so the call count stays at 4.
    await controller.signIn(email: 'owner@example.com', password: 'wrong');
    final state = container.read(signInControllerProvider);
    expect(repository.signInCalls, 4);
    expect(state.hasError, isTrue);
    expect(
      (state.error! as AuthFailure).message,
      matches(RegExp(r'^Too many attempts\. Try again in \d+s\.$')),
    );
  });

  test('a successful sign-in resets the failure counter — 3 more failures afterward are free again', () async {
    final repository = _MixedAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(signInControllerProvider.notifier);

    repository.shouldFail = true;
    for (var i = 0; i < 3; i++) {
      await controller.signIn(email: 'owner@example.com', password: 'wrong');
    }

    repository.shouldFail = false;
    await controller.signIn(email: 'owner@example.com', password: 'correct');
    expect(container.read(signInControllerProvider).hasError, isFalse);

    repository.shouldFail = true;
    for (var i = 0; i < 3; i++) {
      await controller.signIn(email: 'owner@example.com', password: 'wrong');
    }

    // Still no cooldown — the 3 post-success failures are the "free" allotment again, not a
    // continuation of the pre-success count. The repository was genuinely called all 7 times
    // (3 + 1 + 3), proving none of the post-success attempts were blocked client-side.
    expect(repository.signInCalls, 7);
    final finalState = container.read(signInControllerProvider);
    expect(
      (finalState.error! as AuthFailure).message,
      isNot(matches(RegExp(r'^Too many attempts'))),
    );
  });
}

class _MixedAuthRepository implements AuthRepository {
  bool shouldFail = true;
  int signInCalls = 0;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    if (shouldFail) {
      throw const AuthFailure('Invalid login credentials');
    }
  }

  @override
  Future<void> signOut() async {}
}
