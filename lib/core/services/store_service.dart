import '../models/store.dart';
// Note: In a real app complexity, we'd inject a Repository here.
// For this phase, we'll simulate the DB calls or use a placeholder if Supabase isn't fully linked yet in Dart.
// Assuming we need to define the service class structure first.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'location_service.dart';
import '../security/security_guard.dart';
import '../security/device_guard.dart';
import '../auth/session_context.dart';
import 'audit_log_service.dart';
import 'observability_service.dart';

typedef SessionContextResolver = SessionContext? Function();

class StoreService {
  final SecurityGuard _securityGuard;
  final DeviceGuard? _deviceGuard;
  final AuditLogService? _auditLogService;
  final SessionContextResolver? _sessionContextResolver;
  final ObservabilityService _obs = const ObservabilityService();
  Store? _activeStore;

  StoreService({
    LocationService? locationService,
    SecurityGuard? securityGuard,
    DeviceGuard? deviceGuard,
    AuditLogService? auditLogService,
    SessionValidator? sessionValidator,
    SessionContextResolver? sessionContextResolver,
  })  : _securityGuard = securityGuard ??
            SecurityGuard(
              locationService: locationService ?? LocationService(),
              sessionValidator: sessionValidator,
            ),
        _deviceGuard = deviceGuard,
        _auditLogService = auditLogService,
        _sessionContextResolver = sessionContextResolver;

  Store? get activeStore => _activeStore;

  // Mocking list of stores for development until Supabase client is fully wired
  final List<Store> _mockStores = [
    Store(
        id: 'store_1',
        tenantId: 'tenant_1',
        storeName: 'Yangon Main Branch (Mock)',
        currencyCode: 'MMK',
        taxRate: 5.0,
        isGeofenceEnabled: true,
        latitude: 16.8409,
        longitude: 96.1735,
        authorizedBssid: 'aa:bb:cc:dd:ee:ff',
        createdAt: DateTime.now()),
  ];

  /// Fetch stores from Supabase or fallback to Mock
  Future<List<Store>> fetchStores() async {
    try {
      final client = Supabase.instance.client;
      final response = await client.from('stores').select();
      final List<dynamic> data = response as List<dynamic>;
      final stores = data.map((json) => Store.fromJson(json)).toList();
      return _applySessionScope(stores);
    } catch (e) {
      _obs.recordEvent('store_fetch_error_fallback', metadata: {'error': e.toString()});
      return _applySessionScope(_mockStores);
    }
  }

  /// Sets the active store after verifying security constraints
  Future<bool> setActiveStore(Store store) async {
    try {
      if (!_isStoreAllowedBySessionScope(store)) {
        _obs.recordEvent('store_switch_blocked_jwt');
        return false;
      }

      final sessionValid = await _securityGuard.validateSession();
      if (!sessionValid) {
        _obs.recordEvent('store_session_invalid');
        return false;
      }

      final accessAllowed = await _securityGuard.verifyStoreAccess(store);
      if (accessAllowed) {
        _activeStore = store;
        await logAudit(
          actionType: 'store_switch',
          description: 'Store switched to ${store.id}',
        );
        return true;
      } else {
        _obs.recordEvent('store_security_verification_failed', metadata: {'store': store.storeName});
        return false;
      }
    } catch (e) {
      _obs.recordEvent('location_service_error', metadata: {'error': e.toString()});
      return false; // Fail safe
    }
  }

  Future<void> updateStoreTaxRate(String storeId, double newRate) async {
    final session = _sessionContextResolver?.call();
    if (!_isAuthorizedForTaxOverride(session)) {
      _obs.recordEvent('tax_override_blocked', metadata: {'role': session?.role.toString() ?? 'anonymous'});
      throw StateError('Unauthorized to change tax rate.');
    }

    try {
      final client = Supabase.instance.client;
      await client
          .from('stores')
          .update({'tax_rate': newRate}).eq('id', storeId);

      // Update local active store if it matches
      if (_activeStore?.id == storeId) {
        _activeStore = _activeStore!.copyWith(taxRate: newRate);
      }
      _obs.recordEvent('tax_rate_updated', metadata: {'rate': newRate.toString()});
    } catch (e) {
      _obs.recordEvent('tax_rate_update_error_fallback', metadata: {'error': e.toString()});
      // Mock update:
      final index = _mockStores.indexWhere((s) => s.id == storeId);
      if (index != -1) {
        _mockStores[index] = _mockStores[index].copyWith(taxRate: newRate);
        if (_activeStore?.id == storeId) {
          _activeStore = _mockStores[index];
        }
      }
    }
  }

  Future<void> logAudit(
      {required String actionType, required String description}) async {
    final session = _sessionContextResolver?.call();
    final logger = _auditLogService;
    if (logger == null) {
      _obs.recordEvent('audit_local_fallback', metadata: {
        'event': actionType,
        'tenant': _activeStore?.tenantId ?? '',
        'store': _activeStore?.id ?? '',
        'desc': description
      });
      return;
    }
    await logger.log(
      eventType: actionType,
      tenantId: _activeStore?.tenantId ?? session?.tenantId,
      storeId: _activeStore?.id ?? session?.storeId,
      userId: session?.userId,
      eventData: {'description': description},
    );
  }

  /// Verifies if the current transaction is allowed based on security rules
  Future<bool> validateSecurity() async {
    final activeStore = _activeStore;
    if (activeStore == null) return false;
    if (!_isStoreAllowedBySessionScope(activeStore)) return false;

    final session = _sessionContextResolver?.call();
    final sessionValid = await _securityGuard.validateSession();
    if (!sessionValid) return false;

    final tenantId = session?.tenantId;
    final deviceId = session?.deviceId;
    final deviceGuard = _deviceGuard;
    if (deviceGuard != null &&
        tenantId != null &&
        tenantId.isNotEmpty &&
        deviceId != null &&
        deviceId.isNotEmpty) {
      final deviceAuthorized = await deviceGuard.validateDeviceAccess(
        deviceId: deviceId,
        tenantId: tenantId,
        store: activeStore,
      );
      if (!deviceAuthorized) {
        await logAudit(
          actionType: 'device_rejection',
          description:
              'Device validation failed for device=$deviceId store=${activeStore.id}',
        );
        return false;
      }
    }
    return _securityGuard.verifyStoreAccess(activeStore);
  }

  List<Store> _applySessionScope(List<Store> stores) {
    final session = _sessionContextResolver?.call();
    if (session == null || !session.isAuthenticated || session.isExpired) {
      return stores;
    }

    final scopedTenantId = session.tenantId;
    final scopedStoreId = session.storeId;
    return stores.where((store) {
      if (scopedTenantId != null &&
          scopedTenantId.isNotEmpty &&
          store.tenantId != scopedTenantId) {
        return false;
      }
      if (scopedStoreId != null &&
          scopedStoreId.isNotEmpty &&
          store.id != scopedStoreId) {
        return false;
      }
      return true;
    }).toList();
  }

  bool _isStoreAllowedBySessionScope(Store store) {
    final session = _sessionContextResolver?.call();
    if (session == null || !session.isAuthenticated || session.isExpired) {
      return true;
    }

    final scopedTenantId = session.tenantId;
    if (scopedTenantId != null &&
        scopedTenantId.isNotEmpty &&
        store.tenantId != scopedTenantId) {
      return false;
    }

    final scopedStoreId = session.storeId;
    if (scopedStoreId != null &&
        scopedStoreId.isNotEmpty &&
        store.id != scopedStoreId) {
      return false;
    }

    return true;
  }

  bool _isAuthorizedForTaxOverride(SessionContext? session) {
    if (session == null || !session.isAuthenticated || session.isExpired) {
      return false;
    }
    switch (session.role) {
      case UserRole.storeManager:
      case UserRole.tenantAdmin:
      case UserRole.superAdmin:
        return true;
      default:
        return false;
    }
  }
}
