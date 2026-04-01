import '../../core/auth/session_context.dart';
import '../../core/services/audit_log_service.dart';
import 'auth_session_manager.dart';

typedef SessionContextReader = SessionContext? Function();
typedef ClearTenantScope = Future<void> Function();

class LogoutService {
  LogoutService({
    required AuthSessionManager sessionManager,
    required AuditLogService auditLogService,
    required SessionContextReader sessionReader,
    required ClearTenantScope clearTenantScope,
  })  : _sessionManager = sessionManager,
        _auditLogService = auditLogService,
        _sessionReader = sessionReader,
        _clearTenantScope = clearTenantScope;

  final AuthSessionManager _sessionManager;
  final AuditLogService _auditLogService;
  final SessionContextReader _sessionReader;
  final ClearTenantScope _clearTenantScope;

  Future<void> logout({String reason = 'manual_logout'}) async {
    final context = _sessionReader();
    await _auditLogService.log(
      eventType: 'user_logout',
      tenantId: context?.tenantId,
      storeId: context?.storeId,
      userId: context?.userId,
      eventData: {
        'reason': reason,
        'session_id': context?.sessionId,
      },
    );

    await _sessionManager.forceLogout(reason);
    await _clearTenantScope();
  }
}
