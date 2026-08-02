import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// Concrete implementation, per mobile-structure.md §2. Sign-in is a direct
/// client call to Supabase Auth — not a REST endpoint this API owns, per
/// authentication/specification.md §4 — so there is no `data_sources/`
/// split here between "local" and "remote": there is only ever the one
/// remote call, and nothing here reads or writes Drift.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }
}
