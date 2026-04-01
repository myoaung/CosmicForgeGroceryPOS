import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/models/device_registration.dart';
import 'package:grocery/core/models/store.dart';
import 'package:grocery/core/security/device_guard.dart';
import 'package:grocery/core/security/device_registry_service.dart';
import 'package:grocery/core/security/security_guard.dart';

class _FakeDeviceRegistryService extends DeviceRegistryService {
  _FakeDeviceRegistryService(this.registration) : super(null);

  final DeviceRegistration? registration;

  @override
  Future<DeviceRegistration?> fetchRegistration(String deviceId) async {
    if (registration == null) return null;
    if (registration!.deviceId != deviceId) return null;
    return registration;
  }
}

class _FakeSecurityGuard extends SecurityGuard {
  _FakeSecurityGuard({
    required this.networkOk,
    required this.storeOk,
  }) : super(sessionValidator: () async => true);

  final bool networkOk;
  final bool storeOk;

  @override
  Future<bool> checkNetworkTrust({
    String? expectedBssid,
    String? allowedCidr,
  }) async {
    return networkOk;
  }

  @override
  Future<bool> verifyStoreAccess(Store store) async {
    return storeOk;
  }
}

void main() {
  final store = Store(
    id: 'store-1',
    tenantId: 'tenant-1',
    storeName: 'Main',
    currencyCode: 'MMK',
    taxRate: 5,
    isGeofenceEnabled: false,
    createdAt: DateTime(2026, 1, 1),
  );

  final registration = DeviceRegistration(
    id: 'reg-1',
    deviceId: 'device-1',
    tenantId: 'tenant-1',
    storeId: 'store-1',
    deviceName: 'POS-01',
    bssid: 'AA:BB:CC',
    ipRange: '10.0.0.0/24',
    status: 'active',
    registeredAt: DateTime(2026, 1, 1),
  );

  test('rejects device when tenant/store does not match', () async {
    final guard = DeviceGuard(
      deviceRegistryService: _FakeDeviceRegistryService(registration),
      securityGuard: _FakeSecurityGuard(networkOk: true, storeOk: true),
    );

    final result = await guard.verifyDevice(
      deviceId: 'device-1',
      tenantId: 'tenant-x',
      storeId: 'store-1',
    );
    expect(result, isNull);
  });

  test('rejects access when network verification fails', () async {
    final guard = DeviceGuard(
      deviceRegistryService: _FakeDeviceRegistryService(registration),
      securityGuard: _FakeSecurityGuard(networkOk: false, storeOk: true),
    );

    final allowed = await guard.validateDeviceAccess(
      deviceId: 'device-1',
      tenantId: 'tenant-1',
      store: store,
    );
    expect(allowed, false);
  });

  test('allows access for registered active device with valid network/store',
      () async {
    final guard = DeviceGuard(
      deviceRegistryService: _FakeDeviceRegistryService(registration),
      securityGuard: _FakeSecurityGuard(networkOk: true, storeOk: true),
    );

    final allowed = await guard.validateDeviceAccess(
      deviceId: 'device-1',
      tenantId: 'tenant-1',
      store: store,
    );
    expect(allowed, true);
  });

  test('inactive device registration is rejected', () async {
    final inactiveRegistration = DeviceRegistration(
      id: 'reg-2',
      deviceId: 'device-2',
      tenantId: 'tenant-1',
      storeId: 'store-1',
      status: 'disabled',
      registeredAt: DateTime(2026, 1, 1),
    );

    final guard = DeviceGuard(
      deviceRegistryService: _FakeDeviceRegistryService(inactiveRegistration),
      securityGuard: _FakeSecurityGuard(networkOk: true, storeOk: true),
    );

    final result = await guard.verifyDevice(
      deviceId: 'device-2',
      tenantId: 'tenant-1',
      storeId: 'store-1',
    );
    expect(result, isNull);
  });
}
