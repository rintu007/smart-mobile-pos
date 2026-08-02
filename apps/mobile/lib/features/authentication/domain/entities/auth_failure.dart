/// Plain Dart, per mobile-structure.md §2 — the data layer maps whatever
/// Supabase throws into this, so `presentation/` never catches a
/// Supabase-specific exception type directly.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
