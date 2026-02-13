import 'dart:math';

class SecurityGuard {
  // Precise distance calculation for Myanmar Geofencing (Haversine Formula)
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000; // Earth radius in meters
    final dLat = (lat2 - lat1) * (3.141592653589793 / 180);
    final dLon = (lon2 - lon1) * (3.141592653589793 / 180);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
              cos(lat1 * (3.141592653589793 / 180)) * cos(lat2 * (3.141592653589793 / 180)) * (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c; // Returns distance in meters
  }

  static bool isWithinRange(double storeLat, double storeLon, double deviceLat, double deviceLon, {double thresholdMeters = 100.0}) {
    final distance = calculateDistance(storeLat, storeLon, deviceLat, deviceLon);
    return distance <= thresholdMeters;
  }

  static bool isBssidAllowed(String? deviceBssid, String? authorizedBssid) {
    if (authorizedBssid == null || authorizedBssid.isEmpty) return true; // Strict mode might default to false, but for now allow if no guard set? Or maybe false? 
    // Assuming strict:
    if (deviceBssid == null) return false;
    
    // Normalize logic if needed (e.g. lowercase)
    return deviceBssid.toLowerCase() == authorizedBssid.toLowerCase();
  }
}
