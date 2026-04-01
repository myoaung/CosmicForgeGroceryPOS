import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/store.dart';
import '../security/device_guard.dart';
import '../security/device_registry_service.dart';
import '../security/security_guard.dart';
import '../services/audit_log_service.dart';
import '../services/location_service.dart';
import '../services/store_service.dart';
import '../localization/mmk_rounding.dart';
import 'session_provider.dart';

class TenantStoreScope {
  const TenantStoreScope({
    required this.tenantId,
    required this.storeId,
  });

  final String tenantId;
  final String? storeId;
}

// Service Provider
final storeServiceProvider = Provider<StoreService>((ref) {
  SupabaseClient? client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    client = null;
  }

  final securityGuard = SecurityGuard(
    locationService: LocationService(),
    sessionValidator: () async {
      final ctx = ref.read(sessionContextProvider).valueOrNull;
      if (ctx == null) return false;
      return ctx.isAuthenticated && !ctx.isExpired;
    },
  );

  final deviceGuard = DeviceGuard(
    deviceRegistryService: DeviceRegistryService(client),
    securityGuard: securityGuard,
  );

  return StoreService(
    securityGuard: securityGuard,
    deviceGuard: deviceGuard,
    auditLogService: AuditLogService(client: client),
    sessionContextResolver: () => ref.read(sessionContextProvider).valueOrNull,
  );
});

// StateProvider for the Active Store
// In a real app, this might be a StateNotifier that interacts with the Service
final activeStoreProvider = StateProvider<Store?>((ref) => null);

final activeTenantStoreScopeProvider = Provider<TenantStoreScope?>((ref) {
  final activeStore = ref.watch(activeStoreProvider);
  if (activeStore != null) {
    return TenantStoreScope(
      tenantId: activeStore.tenantId,
      storeId: activeStore.id,
    );
  }

  final ctx = ref.watch(sessionContextProvider).valueOrNull;
  if (ctx == null || !ctx.isAuthenticated || ctx.isExpired) {
    return null;
  }
  final tenantId = ctx.tenantId;
  if (tenantId == null || tenantId.isEmpty) {
    return null;
  }
  return TenantStoreScope(
    tenantId: tenantId,
    storeId: ctx.storeId,
  );
});

final scopedTenantIdProvider = Provider<String?>((ref) {
  return ref.watch(activeTenantStoreScopeProvider)?.tenantId;
});

final scopedStoreIdProvider = Provider<String?>((ref) {
  return ref.watch(activeTenantStoreScopeProvider)?.storeId;
});

// Tax Rate Provider is now managed by TaxRateNotifier in tax_provider.dart

// Rounding Logic Provider
final roundingLogicProvider = Provider<Function(double)>((ref) {
  // Always provides the nearest 5/10 MMK rounding logic established in Phase 1
  return roundToNearest5;
});
