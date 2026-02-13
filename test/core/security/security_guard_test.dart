import 'package:flutter_test/flutter_test.dart';
import 'package:grocery/core/security/security_guard.dart';

void main() {
  group('SecurityGuard', () {
    // Coordinates
    final storeLat = 16.8409;
    final storeLon = 96.1735;
    
    test('Haversine: 0 distance for same point', () {
      final distance = SecurityGuard.calculateDistance(storeLat, storeLon, storeLat, storeLon);
      expect(distance, 0.0);
    });

    test('Haversine: Within 100m', () {
      // Slightly offset coordinate (approx 50m away)
      // 0.00045 degrees lat is roughly 50m
      final deviceLat = storeLat + 0.00045; 
      final distance = SecurityGuard.calculateDistance(storeLat, storeLon, deviceLat, storeLon);
      
      expect(distance, lessThan(100.0));
      expect(SecurityGuard.isWithinRange(storeLat, storeLon, deviceLat, storeLon), true);
    });

    test('Haversine: Outside 100m', () {
      // Offset coordinate (approx 150m away)
      // 0.00135 degrees lat is roughly 150m
      final deviceLat = storeLat + 0.0015; 
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
  });
}
