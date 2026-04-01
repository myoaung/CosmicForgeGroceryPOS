import '../models/device_registration.dart';
import '../models/store.dart';
import 'device_registry_service.dart';
import 'security_guard.dart';

class DeviceGuard {
  DeviceGuard({
    required DeviceRegistryService deviceRegistryService,
    required SecurityGuard securityGuard,
  })  : _deviceRegistryService = deviceRegistryService,
        _securityGuard = securityGuard;

  final DeviceRegistryService _deviceRegistryService;
  final SecurityGuard _securityGuard;

  Future<DeviceRegistration?> verifyDevice({
    required String deviceId,
    required String tenantId,
    required String storeId,
  }) async {
    final registration =
        await _deviceRegistryService.fetchRegistration(deviceId);
    if (registration == null) return null;
    if (!registration.isActive) return null;
    if (registration.tenantId != tenantId) return null;
    if (registration.storeId != storeId) return null;
    return registration;
  }

  Future<bool> verifyNetwork(DeviceRegistration registration) {
    return _securityGuard.checkNetworkTrust(
      expectedBssid: registration.bssid,
      allowedCidr: registration.ipRange,
    );
  }

  Future<bool> verifyStoreAuthorization({
    required Store store,
    required DeviceRegistration registration,
  }) async {
    if (registration.storeId != store.id) return false;
    return _securityGuard.verifyStoreAccess(store);
  }

  Future<bool> validateDeviceAccess({
    required String deviceId,
    required String tenantId,
    required Store store,
  }) async {
    final registration = await verifyDevice(
      deviceId: deviceId,
      tenantId: tenantId,
      storeId: store.id,
    );
    if (registration == null) return false;

    final networkOk = await verifyNetwork(registration);
    if (!networkOk) return false;

    return verifyStoreAuthorization(store: store, registration: registration);
  }
}
