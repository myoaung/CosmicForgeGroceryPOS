import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:grocery/core/models/device_registration.dart';
import 'package:grocery/core/models/store.dart';
import 'package:grocery/core/security/security_guard.dart';
import 'package:grocery/core/services/location_service.dart';

class FakeLocationService extends LocationService {
  FakeLocationService({
    this.lat = 16.8409,
    this.lon = 96.1735,
    this.bssid = 'aa:bb:cc',
    this.ip = '10.1.2.5',
  });

  final double lat;
  final double lon;
  final String? bssid;
  final String? ip;

  @override
  Future<Position> getCurrentPosition() async {
    return Position(
      longitude: lon,
      latitude: lat,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
  }

  @override
  Future<String?> getWifiBssid() async => bssid;

  @override
  Future<String?> getWifiIp() async => ip;
}

void main() {
  group('SecurityGuard', () {
    // Coordinates
    const storeLat = 16.8409;
    const storeLon = 96.1735;
    
    test('Haversine: 0 distance for same point', () {
      final distance = SecurityGuard.calculateDistance(storeLat, storeLon, storeLat, storeLon);
      expect(distance, 0.0);
    });

    test('Haversine: Within 100m', () {
      // Slightly offset coordinate (approx 50m away)
      // 0.00045 degrees lat is roughly 50m
      const deviceLat = storeLat + 0.00045; 
      final distance = SecurityGuard.calculateDistance(storeLat, storeLon, deviceLat, storeLon);
      
      expect(distance, lessThan(100.0));
      expect(SecurityGuard.isWithinRange(storeLat, storeLon, deviceLat, storeLon), true);
    });

    test('Haversine: Outside 100m', () {
      // Offset coordinate (approx 150m away)
      // 0.00135 degrees lat is roughly 150m
      const deviceLat = storeLat + 0.0015; 
      final distance = SecurityGuard.calculateDistance(storeLat, storeLon, deviceLat, storeLon);
      
      expect(distance, greaterThan(100.0));
      expect(SecurityGuard.isWithinRange(storeLat, storeLon, deviceLat, storeLon), false);
    });

    test('BSSID Check', () {
      expect(SecurityGuard.isBssidAllowed('aa:bb:cc', 'aa:bb:cc'), true);
      // Case sensitive check should return true because of toLowerCase()
      expect(SecurityGuard.isBssidAllowed('aa:bb:cc', 'AA:BB:CC'), true);
      expect(SecurityGuard.isBssidAllowed('aa:bb:cc', 'xx:yy:zz'), false);
    });

    test('validateSession delegates to session validator', () async {
      final okGuard = SecurityGuard(
        locationService: FakeLocationService(),
        sessionValidator: () async => true,
      );
      final deniedGuard = SecurityGuard(
        locationService: FakeLocationService(),
        sessionValidator: () async => false,
      );
      expect(await okGuard.validateSession(), true);
      expect(await deniedGuard.validateSession(), false);
    });

    test('verifyDevice validates bssid and ip range', () async {
      final guard = SecurityGuard(
        locationService: FakeLocationService(bssid: 'aa:bb:cc', ip: '10.1.2.5'),
      );
      final device = DeviceRegistration(
        deviceId: 'device-1',
        tenantId: 'tenant-1',
        storeId: 'store-1',
        bssid: 'AA:BB:CC',
        ipRange: '10.1.2.0/24',
        registeredAt: DateTime.now(),
      );

      expect(await guard.verifyDevice(device), true);
    });

    test('verifyStoreAccess uses geofence + bssid', () async {
      final guard = SecurityGuard(
        locationService: FakeLocationService(lat: storeLat, lon: storeLon, bssid: 'aa:bb:cc'),
      );
      final store = Store(
        id: 'store-1',
        tenantId: 'tenant-1',
        storeName: 'Main',
        currencyCode: 'MMK',
        taxRate: 5,
        isGeofenceEnabled: true,
        authorizedBssid: 'aa:bb:cc',
        latitude: storeLat,
        longitude: storeLon,
        createdAt: DateTime.now(),
      );

      expect(await guard.verifyStoreAccess(store), true);
    });
  });
}
