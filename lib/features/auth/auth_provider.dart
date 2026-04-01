import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/session_context.dart';
import '../../core/providers/session_provider.dart';
import '../../core/providers/store_provider.dart';
import '../../core/security/secure_storage_service.dart';
import '../../core/services/audit_log_service.dart';
import 'auth_service.dart';
import 'auth_session_manager.dart';
import 'logout_service.dart';

enum AuthStatus {
  unknown,
  authenticating,
  authenticated,
  unauthenticated,
  error,
}

class AuthViewState {
  const AuthViewState({
    required this.status,
    this.errorMessage,
    this.pinMode = false,
  });

  final AuthStatus status;
  final String? errorMessage;
  final bool pinMode;

  AuthViewState copyWith({
    AuthStatus? status,
    String? errorMessage,
    bool clearError = false,
    bool? pinMode,
  }) {
    return AuthViewState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pinMode: pinMode ?? this.pinMode,
    );
  }
}

SupabaseClient? _readSupabaseClient() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final auditLogServiceProvider = Provider<AuditLogService>((ref) {
  return AuditLogService(client: _readSupabaseClient());
});

final authSessionManagerProvider = Provider<AuthSessionManager>((ref) {
  final manager = AuthSessionManager(
    client: _readSupabaseClient(),
    secureStorage: ref.watch(secureStorageServiceProvider),
    onForcedLogout: (reason) async {
      ref.read(activeStoreProvider.notifier).state = null;
      await ref.read(secureStorageServiceProvider).clearSession();
      await ref.read(auditLogServiceProvider).log(
        eventType: 'auth_failure',
        eventData: {'reason': reason},
      );
    },
  );

  ref.onDispose(() async {
    await manager.dispose();
  });
  return manager;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    client: _readSupabaseClient(),
    sessionManager: ref.watch(authSessionManagerProvider),
    auditLogService: ref.watch(auditLogServiceProvider),
  );
});

final logoutServiceProvider = Provider<LogoutService>((ref) {
  return LogoutService(
    sessionManager: ref.watch(authSessionManagerProvider),
    auditLogService: ref.watch(auditLogServiceProvider),
    sessionReader: () => ref.read(sessionContextProvider).valueOrNull,
    clearTenantScope: () async {
      ref.read(activeStoreProvider.notifier).state = null;
    },
  );
});

final authBootstrapProvider = Provider<void>((ref) {
  unawaited(ref.read(authSessionManagerProvider).start());
});

final authStateProvider =
    StateNotifierProvider<AuthNotifier, AuthViewState>((ref) {
  return AuthNotifier(
    ref: ref,
    authService: ref.watch(authServiceProvider),
    logoutService: ref.watch(logoutServiceProvider),
  );
});

final userRoleProvider = Provider<UserRole>((ref) {
  final session = ref.watch(sessionContextProvider).valueOrNull;
  if (session == null || !session.isAuthenticated || session.isExpired) {
    return UserRole.unknown;
  }
  return session.role;
});

final canCheckoutProvider = Provider<bool>((ref) {
  final role = ref.watch(userRoleProvider);
  return role == UserRole.cashier ||
      role == UserRole.storeManager ||
      role == UserRole.tenantAdmin ||
      role == UserRole.superAdmin;
});

final canManageInventoryProvider = Provider<bool>((ref) {
  final role = ref.watch(userRoleProvider);
  return role == UserRole.storeManager ||
      role == UserRole.tenantAdmin ||
      role == UserRole.superAdmin;
});

final canManageUsersProvider = Provider<bool>((ref) {
  final role = ref.watch(userRoleProvider);
  return role == UserRole.tenantAdmin || role == UserRole.superAdmin;
});

final canViewReportsProvider = Provider<bool>((ref) {
  final role = ref.watch(userRoleProvider);
  return role == UserRole.auditor ||
      role == UserRole.storeManager ||
      role == UserRole.tenantAdmin ||
      role == UserRole.superAdmin;
});

class AuthNotifier extends StateNotifier<AuthViewState> {
  AuthNotifier({
    required Ref ref,
    required AuthService authService,
    required LogoutService logoutService,
  })  : _ref = ref,
        _authService = authService,
        _logoutService = logoutService,
        super(const AuthViewState(status: AuthStatus.unknown)) {
    _wireSessionState();
  }

  final Ref _ref;
  final AuthService _authService;
  final LogoutService _logoutService;

  void _wireSessionState() {
    _ref.listen<AsyncValue<SessionContext>>(sessionContextProvider,
        (previous, next) {
      final context = next.valueOrNull;
      if (context == null || !context.isAuthenticated || context.isExpired) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          clearError: true,
        );
        return;
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        clearError: true,
      );
    });
  }

  void togglePinMode() {
    state = state.copyWith(pinMode: !state.pinMode, clearError: true);
  }

  Future<void> loginWithEmailPassword({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);
    try {
      await _authService.ensureTls();
      await _authService.signInWithEmailPassword(
        email: email,
        password: password,
        deviceId: deviceId,
      );
      state =
          state.copyWith(status: AuthStatus.authenticated, clearError: true);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loginWithPin({
    required String email,
    required String pin,
    String? deviceId,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);
    try {
      await _authService.ensureTls();
      await _authService.signInWithPin(
        email: email,
        pin: pin,
        deviceId: deviceId,
      );
      state =
          state.copyWith(status: AuthStatus.authenticated, clearError: true);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.authenticating, clearError: true);
    await _logoutService.logout();
    state =
        state.copyWith(status: AuthStatus.unauthenticated, clearError: true);
  }
}
