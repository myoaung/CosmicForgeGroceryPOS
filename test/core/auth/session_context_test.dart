import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/auth/session_context.dart';

String _jwt(Map<String, dynamic> payload) {
  String b64(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  final header = b64({'alg': 'none', 'typ': 'JWT'});
  final body = b64(payload);
  return '$header.$body.signature';
}

void main() {
  test('parses tenant/store/role/device/session claims from access token', () {
    final token = _jwt({
      'sub': 'user-1',
      'tenant_id': 'tenant-a',
      'store_id': 'store-a',
      'role': 'store_manager',
      'device_id': 'device-1',
      'session_id': 'sess-1',
    });

    final context = SessionContext.fromAccessTokenForTest(token);
    expect(context.userId, 'user-1');
    expect(context.tenantId, 'tenant-a');
    expect(context.storeId, 'store-a');
    expect(context.role, UserRole.storeManager);
    expect(context.deviceId, 'device-1');
    expect(context.sessionId, 'sess-1');
  });

  test('invalid token maps to unknown role and no tenant/store scope', () {
    final context =
        SessionContext.fromAccessTokenForTest('invalid.token.value');
    expect(context.role, UserRole.unknown);
    expect(context.tenantId, isNull);
    expect(context.storeId, isNull);
    expect(context.deviceId, isNull);
    expect(context.sessionId, isNull);
  });
}
