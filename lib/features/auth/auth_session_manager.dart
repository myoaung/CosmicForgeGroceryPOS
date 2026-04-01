import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/security/secure_storage_service.dart';

typedef ForcedLogoutCallback = Future<void> Function(String reason);

class AuthSessionManager {
  AuthSessionManager({
    required SupabaseClient? client,
    required SecureStorageService secureStorage,
    this.onForcedLogout,
  })  : _client = client,
        _secureStorage = secureStorage;

  final SupabaseClient? _client;
  final SecureStorageService _secureStorage;
  final ForcedLogoutCallback? onForcedLogout;

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _refreshTimer;

  Future<void> start() async {
    final client = _client;
    if (client == null) return;

    _authSubscription?.cancel();
    _authSubscription = client.auth.onAuthStateChange.listen((event) async {
      await _handleSessionChange(event.session);
    });

    await _handleSessionChange(client.auth.currentSession);
  }

  Future<void> dispose() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    await _authSubscription?.cancel();
    _authSubscription = null;
  }

  Future<void> handlePostLogin(Session? session) =>
      _handleSessionChange(session);

  Future<void> refreshNow() async {
    final client = _client;
    if (client == null) {
      await _forceLogout('supabase_unavailable');
      return;
    }

    try {
      final response = await client.auth.refreshSession();
      final session = response.session;
      if (session == null) {
        await _forceLogout('refresh_failed_no_session');
        return;
      }
      await _handleSessionChange(session);
    } catch (e) {
      await _forceLogout('refresh_failed:$e');
    }
  }

  Future<void> forceLogout(String reason) =>
      _forceLogout(reason, signOutRemote: true);

  Future<void> _handleSessionChange(Session? session) async {
    if (session == null) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      await _secureStorage.clearSession();
      return;
    }

    await _secureStorage.persistSession(session);
    _scheduleRefresh(session);
  }

  void _scheduleRefresh(Session session) {
    _refreshTimer?.cancel();

    final expiresAtSeconds = session.expiresAt;
    if (expiresAtSeconds == null) {
      return;
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        expiresAtSeconds * 1000,
        isUtc: true);
    final now = DateTime.now().toUtc();
    var delay = expiresAt.difference(now) - const Duration(minutes: 2);
    if (delay <= Duration.zero) {
      delay = const Duration(seconds: 1);
    }

    _refreshTimer = Timer(delay, () async {
      await refreshNow();
    });
  }

  Future<void> _forceLogout(String reason, {bool signOutRemote = false}) async {
    _refreshTimer?.cancel();
    _refreshTimer = null;

    final client = _client;
    if (signOutRemote && client != null) {
      try {
        await client.auth.signOut(scope: SignOutScope.local);
      } catch (e) {
        debugPrint('AuthSessionManager: signOut failed: $e');
      }
    }

    await _secureStorage.clearSession();
    if (onForcedLogout != null) {
      await onForcedLogout!(reason);
    }
  }
}
