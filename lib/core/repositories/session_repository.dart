// Session/auth abstraction to keep UI free of direct Supabase/DB calls.
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class SessionRepository {
  Future<String?> currentUserId();
  Future<void> signOut();
  Future<bool> hasValidSession();
}

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String?> currentUserId() async => _client.auth.currentUser?.id;

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<bool> hasValidSession() async => _client.auth.currentSession != null;
}

class InMemorySessionRepository implements SessionRepository {
  String? _userId;

  void seed(String? userId) => _userId = userId;

  @override
  Future<String?> currentUserId() async => _userId;

  @override
  Future<void> signOut() async {
    _userId = null;
  }

  @override
  Future<bool> hasValidSession() async => _userId != null;
}
