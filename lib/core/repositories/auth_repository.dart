// Placeholder for future authentication/session handling.
// Keeps UI decoupled from the underlying auth provider.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthRepository {
  Future<bool> signIn(String email, String password);
  Future<void> signOut();
  Future<String?> currentUserId();
}

/// ⚠️ FOR TESTS AND DEV SCAFFOLDING ONLY.
///
/// This class bypasses all security guards defined in [AuthService]:
///   - No TLS verification ([AuthService.ensureTls])
///   - No password policy check ([AuthService.validatePasswordPolicy])
///   - No audit log entry
///
/// Production code must use [authServiceProvider] / [AuthService] instead.
@visibleForTesting
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> signIn(String email, String password) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user != null;
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<String?> currentUserId() async => _client.auth.currentUser?.id;
}

class MockAuthRepository implements AuthRepository {
  String? _userId;

  @override
  Future<bool> signIn(String email, String password) async {
    _userId = 'mock-user';
    return true;
  }

  @override
  Future<void> signOut() async {
    _userId = null;
  }

  @override
  Future<String?> currentUserId() async => _userId;
}
