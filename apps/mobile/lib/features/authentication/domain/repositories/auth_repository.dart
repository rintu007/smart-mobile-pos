/// Abstract interface only, per mobile-structure.md §2 — no Flutter, no
/// Supabase import here. `data/repositories/` provides the concrete
/// implementation.
abstract class AuthRepository {
  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
