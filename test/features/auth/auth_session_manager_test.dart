import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/security/secure_storage_service.dart';
import 'package:grocery/features/auth/auth_session_manager.dart';

void main() {
  test('forceLogout clears secure session and invokes callback', () async {
    final storage = SecureStorageService(storage: InMemorySecureStoragePort());
    await storage.clearSession();

    String? callbackReason;
    final manager = AuthSessionManager(
      client: null,
      secureStorage: storage,
      onForcedLogout: (reason) async {
        callbackReason = reason;
      },
    );

    await manager.forceLogout('manual_test');

    expect(callbackReason, 'manual_test');
    expect(await storage.readAccessToken(), isNull);
    expect(await storage.readRefreshToken(), isNull);
  });
}
