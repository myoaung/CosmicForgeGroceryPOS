import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/security/secure_storage_service.dart';
import 'package:grocery/core/services/audit_log_service.dart';
import 'package:grocery/features/auth/auth_service.dart';
import 'package:grocery/features/auth/auth_session_manager.dart';

void main() {
  test('password policy enforces enterprise complexity', () {
    final manager = AuthSessionManager(
      client: null,
      secureStorage: SecureStorageService(storage: InMemorySecureStoragePort()),
    );
    final service = AuthService(
      client: null,
      sessionManager: manager,
      auditLogService: AuditLogService(client: null),
    );

    expect(service.validatePasswordPolicy('weak'), isNotNull);
    expect(service.validatePasswordPolicy('NoSpecial123'), isNotNull);
    expect(service.validatePasswordPolicy('Strong@123'), isNull);
  });
}
