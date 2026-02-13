import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/services/store_service.dart';
import 'package:grocery/core/models/store.dart';
import 'package:grocery/core/services/location_service.dart';
// import 'package:mockito/mockito.dart'; // Using explicit Fake instead of mockito to avoid code gen for now
import 'package:geolocator/geolocator.dart';

// Fake Position for testing
Position getMockPosition(double lat, double lng) {
  return Position(
    longitude: lng,
    latitude: lat,
    timestamp: DateTime.now(),
    accuracy: 0.0,
    altitude: 0.0,
    heading: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0, 
    altitudeAccuracy: 0.0, 
    headingAccuracy: 0.0,
  );
}

class FakeLocationService extends LocationService {
  final double lat;
  final double lng;

  FakeLocationService(this.lat, this.lng);

  @override
  Future<Position> getCurrentPosition() async {
    return getMockPosition(lat, lng);
  }
}

void main() {
  group('StoreService', () {
    test('fetchStores returns mock data (when Supabase not init)', () async {
      final storeService = StoreService();
      final stores = await storeService.fetchStores();
      expect(stores.length, 1); // We have 1 mock store in the updated list
      expect(stores.first.storeName, contains('Mock'));
    });

    test('setActiveStore ALLOWS switch if within 100m', () async {
      // Store at 16.8409, 96.1735
      // Device at same location
      final locationService = FakeLocationService(16.8409, 96.1735);
      final storeService = StoreService(locationService: locationService);

      final store = Store(
        id: 'test_store',
        tenantId: 'tenant_1',
        storeName: 'Test Store',
        currencyCode: 'MMK',
        taxRate: 5.0,
        isGeofenceEnabled: true,
        latitude: 16.8409,
        longitude: 96.1735,
        createdAt: DateTime.now(),
      );

      final result = await storeService.setActiveStore(store);
      expect(result, true);
      expect(storeService.activeStore, store);
    });

    test('setActiveStore BLOCKS switch if outside 100m', () async {
      // Store at 16.8409, 96.1735
      // Device far away (e.g. +0.01 deg is > 1km)
      final locationService = FakeLocationService(16.9000, 96.2000);
      final storeService = StoreService(locationService: locationService);

      final store = Store(
        id: 'test_store',
        tenantId: 'tenant_1',
        storeName: 'Test Store',
        currencyCode: 'MMK',
        taxRate: 5.0,
        isGeofenceEnabled: true,
        latitude: 16.8409,
        longitude: 96.1735,
        createdAt: DateTime.now(),
      );

      final result = await storeService.setActiveStore(store);
      expect(result, false);
      expect(storeService.activeStore, isNull);
    });

    test('updateTaxRate updates the rate (Mock Fallback)', () async {
      final locationService = FakeLocationService(16.8409, 96.1735);
      final storeService = StoreService(locationService: locationService);
      
      // First fetch to populate internal mock list
      final stores = await storeService.fetchStores();
      final targetStore = stores.first;

      await storeService.setActiveStore(targetStore);
      expect(storeService.activeStore!.taxRate, 5.0);

      await storeService.updateStoreTaxRate(targetStore.id, 0.0);

      // Verify active store is updated
      expect(storeService.activeStore!.taxRate, 0.0);
    });
  });
}
