import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/session_context.dart';
import '../../core/services/audit_log_service.dart';
import 'auth_session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService({
    required SupabaseClient? client,
    required AuthSessionManager sessionManager,
    required AuditLogService auditLogService,
  })  : _client = client,
        _sessionManager = sessionManager,
        _auditLogService = auditLogService;

  final SupabaseClient? _client;
  final AuthSessionManager _sessionManager;
  final AuditLogService _auditLogService;

  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _number = RegExp(r'[0-9]');
  static final RegExp _special =
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]\\\/+=;]');
  static final RegExp _pin = RegExp(r'^[0-9]{4,8}$');

  String? validatePasswordPolicy(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (!_uppercase.hasMatch(password)) {
      return 'Password must include an uppercase character.';
    }
    if (!_number.hasMatch(password)) {
      return 'Password must include a number.';
    }
    if (!_special.hasMatch(password)) {
      return 'Password must include a special character.';
    }
    return null;
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not initialized.');
    }

    final passwordError = validatePasswordPolicy(password);
    if (passwordError != null) {
      throw ArgumentError(passwordError);
    }

    final authResponse = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (authResponse.session == null || authResponse.user == null) {
      throw StateError('Authentication failed.');
    }

    await _sessionManager.handlePostLogin(authResponse.session);
    final context = SessionContext.fromSupabaseSession(authResponse.session);
    await _auditLogService.log(
      eventType: 'user_login',
      tenantId: context.tenantId,
      storeId: context.storeId,
      userId: context.userId,
      eventData: {
        'method': 'email_password',
        'device_id': deviceId ?? context.deviceId,
      },
    );
  }

  Future<void> signInWithPin({
    required String email,
    required String pin,
    String? deviceId,
  }) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not initialized.');
    }
    if (!_pin.hasMatch(pin)) {
      throw ArgumentError('PIN must be 4-8 digits.');
    }

    // Local Rate Limiting
    final prefs = await SharedPreferences.getInstance();
    final prefsKey = 'pin_attempts_${email.trim().toLowerCase()}_${deviceId ?? "default"}';
    final now = DateTime.now();
    
    List<String> rawAttempts = prefs.getStringList(prefsKey) ?? [];
    List<DateTime> attempts = rawAttempts
        .map((e) => DateTime.tryParse(e))
        .whereType<DateTime>()
        .where((d) => now.difference(d).inHours < 24)
        .toList();

    if (attempts.length >= 10) {
      throw StateError('Account locked. Manager override required.');
    }
    
    final attempts5m = attempts.where((d) => now.difference(d).inMinutes < 5).length;
    if (attempts5m >= 5) {
      throw StateError('Too many PIN attempts. Please wait 5 minutes.');
    }
    
    final attempts1m = attempts.where((d) => now.difference(d).inMinutes < 1).length;
    if (attempts1m >= 3) {
      throw StateError('Too many PIN attempts. Please wait 1 minute.');
    }

    dynamic response;
    try {
      response = await client.rpc(
        'pin_login',
        params: {
          'email_input': email.trim(),
          'pin_input': pin,
          'device_id_input': deviceId,
        },
      );
    } catch (e) {
      attempts.add(now);
      await prefs.setStringList(prefsKey, attempts.map((d) => d.toIso8601String()).toList());
      rethrow;
    }

    if (response == null || response is! Map) {
      attempts.add(now);
      await prefs.setStringList(prefsKey, attempts.map((d) => d.toIso8601String()).toList());
      throw StateError('PIN login is not available.');
    }

    final refreshToken = response['refresh_token']?.toString();
    if (refreshToken == null || refreshToken.isEmpty) {
      attempts.add(now);
      await prefs.setStringList(prefsKey, attempts.map((d) => d.toIso8601String()).toList());
      throw StateError('PIN login failed: no refresh token returned.');
    }

    // On success, clear local attempts
    await prefs.remove(prefsKey);

    final authResponse = await client.auth.setSession(refreshToken);
    final session = authResponse.session;
    if (session == null) {
      throw StateError('PIN login failed: invalid session.');
    }

    await _sessionManager.handlePostLogin(session);
    final context = SessionContext.fromSupabaseSession(session);
    await _auditLogService.log(
      eventType: 'user_login',
      tenantId: context.tenantId,
      storeId: context.storeId,
      userId: context.userId,
      eventData: {
        'method': 'pin',
        'device_id': deviceId ?? context.deviceId,
      },
    );
  }

  Future<void> ensureTls() async {
    final client = _client;
    if (client == null) return;

    final url = client.rest.url.toString().toLowerCase();
    if (!url.startsWith('https://')) {
      debugPrint('AuthService: non-TLS URL detected: $url');
      throw StateError('Insecure transport detected. HTTPS is required.');
    }
  }
}
