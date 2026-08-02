import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Session/token primitives shared by every feature's data layer, per
/// mobile-structure.md §1 (`core/auth/`). Every feature reads the current
/// session through this provider rather than touching
/// `Supabase.instance.client.auth` directly — this is the one seam that
/// would need to change if the auth backend ever did.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// The current session, synchronously — `null` when signed out. Used by the
/// router's redirect guard, which needs a value immediately rather than
/// waiting on the stream's first event.
Session? currentSession() => Supabase.instance.client.auth.currentSession;
