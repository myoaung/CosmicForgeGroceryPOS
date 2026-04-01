import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole {
  cashier,
  storeManager,
  tenantAdmin,
  superAdmin,
  auditor,
  unknown,
}

class SessionContext {
  const SessionContext({
    required this.isAuthenticated,
    required this.userId,
    required this.tenantId,
    required this.storeId,
    required this.role,
    required this.deviceId,
    required this.sessionId,
    this.issuedAt,
    this.expiresAt,
  });

  final bool isAuthenticated;
  final String? userId;
  final String? tenantId;
  final String? storeId;
  final UserRole role;
  final String? deviceId;
  final String? sessionId;
  final DateTime? issuedAt;
  final DateTime? expiresAt;

  bool get isAdmin =>
      role == UserRole.tenantAdmin || role == UserRole.superAdmin;
  bool get hasTenantStoreScope =>
      tenantId != null &&
      tenantId!.isNotEmpty &&
      storeId != null &&
      storeId!.isNotEmpty;

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  static SessionContext unauthenticated() => const SessionContext(
        isAuthenticated: false,
        userId: null,
        tenantId: null,
        storeId: null,
        role: UserRole.unknown,
        deviceId: null,
        sessionId: null,
      );

  static SessionContext fromSupabaseSession(Session? session) {
    if (session == null) {
      return unauthenticated();
    }

    final claims = _parseJwtClaims(session.accessToken);
    final appMeta = claims['app_metadata'] is Map
        ? claims['app_metadata'] as Map
        : const {};
    final userMeta = claims['user_metadata'] is Map
        ? claims['user_metadata'] as Map
        : const {};

    final tenantId =
        _readClaim(claims, appMeta, userMeta, const ['tenant_id', 'tenantId']);
    final storeId =
        _readClaim(claims, appMeta, userMeta, const ['store_id', 'storeId']);
    final roleValue = _readClaim(claims, appMeta, userMeta, const ['role']);
    final deviceId =
        _readClaim(claims, appMeta, userMeta, const ['device_id', 'deviceId']);
    final sessionId = _readClaim(
        claims, appMeta, userMeta, const ['session_id', 'sessionId']);

    final iat = _epochToDateTime(claims['iat']);
    final exp = _epochToDateTime(claims['exp']);

    final authenticated = session.user.id.isNotEmpty;

    return SessionContext(
      isAuthenticated: authenticated,
      userId: session.user.id,
      tenantId: tenantId,
      storeId: storeId,
      role: _parseRole(roleValue),
      deviceId: deviceId,
      sessionId: sessionId,
      issuedAt: iat,
      expiresAt: exp,
    );
  }

  static SessionContext fromAccessTokenForTest(String token, {String? userId}) {
    final claims = _parseJwtClaims(token);
    final appMeta = claims['app_metadata'] is Map
        ? claims['app_metadata'] as Map
        : const {};
    final userMeta = claims['user_metadata'] is Map
        ? claims['user_metadata'] as Map
        : const {};

    return SessionContext(
      isAuthenticated: true,
      userId: userId ?? _asString(claims['sub']),
      tenantId: _readClaim(
          claims, appMeta, userMeta, const ['tenant_id', 'tenantId']),
      storeId:
          _readClaim(claims, appMeta, userMeta, const ['store_id', 'storeId']),
      role: _parseRole(_readClaim(claims, appMeta, userMeta, const ['role'])),
      deviceId: _readClaim(
          claims, appMeta, userMeta, const ['device_id', 'deviceId']),
      sessionId: _readClaim(
          claims, appMeta, userMeta, const ['session_id', 'sessionId']),
      issuedAt: _epochToDateTime(claims['iat']),
      expiresAt: _epochToDateTime(claims['exp']),
    );
  }

  static Map<String, dynamic> _parseJwtClaims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return const {};
      }
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }

  // NOTE: Only root JWT claims and app_metadata are trusted sources.
  // user_metadata is deliberately excluded — it is writable by any authenticated
  // user via auth.updateUser() and must never be used for authoritative claims
  // such as tenant_id, store_id, or role.
  static String? _readClaim(
    Map<String, dynamic> claims,
    Map appMeta,
    Map userMeta, // retained in signature for call-site compatibility
    List<String> keys,
  ) {
    for (final key in keys) {
      // 1. Try root JWT payload (highest trust — server-signed).
      final direct = _asString(claims[key]);
      if (direct != null && direct.isNotEmpty) {
        return direct;
      }

      // 2. Try app_metadata (admin-managed, not user-editable).
      final app = _asString(appMeta[key]);
      if (app != null && app.isNotEmpty) {
        return app;
      }

      // 3. user_metadata is NOT checked — it is user-writable and untrusted.
    }
    return null;
  }

  static DateTime? _epochToDateTime(dynamic value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return DateTime.fromMillisecondsSinceEpoch(parsed * 1000, isUtc: true);
      }
    }
    return null;
  }

  static UserRole _parseRole(String? role) {
    switch ((role ?? '').toLowerCase()) {
      case 'cashier':
        return UserRole.cashier;
      case 'manager':
      case 'store_manager':
      case 'storemanager':
        return UserRole.storeManager;
      case 'tenant_admin':
      case 'tenantadmin':
        return UserRole.tenantAdmin;
      case 'super_admin':
      case 'superadmin':
        return UserRole.superAdmin;
      case 'auditor':
        return UserRole.auditor;
      default:
        return UserRole.unknown;
    }
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }
}
