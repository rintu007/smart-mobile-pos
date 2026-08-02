import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/authentication/domain/entities/auth_failure.dart';
import 'package:mobile/features/authentication/domain/repositories/auth_repository.dart';
import 'package:mobile/features/authentication/presentation/providers/auth_providers.dart';
import 'package:mobile/features/authentication/presentation/screens/login_screen.dart';

/// A fake, not a mock — this feature has exactly one collaborator
/// (`AuthRepository`), so a hand-written fake is simpler than pulling in a
/// mocking package for one interface.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.signInBehavior});

  /// If null, `signInWithPassword` succeeds. If set, it's invoked instead —
  /// tests use this to inject a delay (proving the loading state renders)
  /// or a thrown `AuthFailure` (proving the error state renders).
  final Future<void> Function()? signInBehavior;

  bool signInCalled = false;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInCalled = true;
    if (signInBehavior != null) {
      await signInBehavior!();
    }
  }

  @override
  Future<void> signOut() async {}
}

Widget _wrap(Widget child, {required AuthRepository repository}) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('renders email/password fields and a disabled-until-valid submit button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const LoginScreen(), repository: _FakeAuthRepository()),
    );

    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
  });

  testWidgets('submitting empty fields shows inline validation and calls nothing', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_wrap(const LoginScreen(), repository: repository));

    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(repository.signInCalled, isFalse);
  });

  testWidgets('valid submit shows the loading state while the call is in flight', (
    tester,
  ) async {
    final completer = Future<void>.delayed(const Duration(milliseconds: 50));
    final repository = _FakeAuthRepository(signInBehavior: () => completer);
    await tester.pumpWidget(_wrap(const LoginScreen(), repository: repository));

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'owner@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'correct-horse-battery-staple',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repository.signInCalled, isTrue);

    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('login_error_text')), findsNothing);
  });

  testWidgets('a thrown AuthFailure renders its message as inline error text', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      signInBehavior: () async => throw const AuthFailure('Invalid login credentials'),
    );
    await tester.pumpWidget(_wrap(const LoginScreen(), repository: repository));

    await tester.enterText(
      find.byKey(const Key('login_email_field')),
      'owner@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_error_text')), findsOneWidget);
    expect(find.text('Invalid login credentials'), findsOneWidget);
  });
}
