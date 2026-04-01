import 'dart:math';

import '../models/device_registration.dart';
import '../models/store.dart';
import '../services/location_service.dart';

typedef SessionValidator = Future<bool> Function();

class SecurityGuard {
  final LocationService _locationService;
  final SessionValidator _sessionValidator;

  SecurityGuard({
    LocationService? locationService,
    SessionValidator? sessionValidator,
  })  : _locationService = locationService ?? LocationService(),
        _sessionValidator = sessionValidator ?? (() async => true);

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
    if (authorizedBssid == null || authorizedBssid.isEmpty) return true;
    if (deviceBssid == null) return false;
    
    return deviceBssid.toLowerCase() == authorizedBssid.toLowerCase();
  }

  Future<bool> verifyDevice(DeviceRegistration registration) async {
    final bssidAllowed = await checkNetworkTrust(
      expectedBssid: registration.bssid,
      allowedCidr: registration.ipRange,
    );
    return bssidAllowed;
  }

  Future<bool> verifyStoreAccess(Store store) async {
    if (!store.isGeofenceEnabled) return true;
    if (store.latitude == null || store.longitude == null) return false;

    final position = await _locationService.getCurrentPosition();
    final inRange = isWithinRange(
      store.latitude!,
      store.longitude!,
      position.latitude,
      position.longitude,
    );
    if (!inRange) {
      return false;
    }

    final bssid = await _locationService.getWifiBssid();
    return isBssidAllowed(bssid, store.authorizedBssid);
  }

  Future<bool> validateSession() => _sessionValidator();

  Future<bool> checkNetworkTrust({
    String? expectedBssid,
    String? allowedCidr,
  }) async {
    final bssid = await _locationService.getWifiBssid();
    final bssidOk = isBssidAllowed(bssid, expectedBssid);
    if (!bssidOk) return false;

    if (allowedCidr == null || allowedCidr.isEmpty) return true;
    final ip = await _locationService.getWifiIp();
    if (ip == null || ip.isEmpty) return false;
    return _isIpInCidr(ip, allowedCidr);
  }

  bool _isIpInCidr(String ip, String cidr) {
    final parts = cidr.split('/');
    if (parts.length != 2) return false;

    final network = _ipv4ToInt(parts[0]);
    final ipValue = _ipv4ToInt(ip);
    final prefix = int.tryParse(parts[1]);
    if (network == null || ipValue == null || prefix == null || prefix < 0 || prefix > 32) {
      return false;
    }

    final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
    return (network & mask) == (ipValue & mask);
  }

  int? _ipv4ToInt(String value) {
    final octets = value.split('.');
    if (octets.length != 4) return null;
    var result = 0;
    for (final octet in octets) {
      final n = int.tryParse(octet);
      if (n == null || n < 0 || n > 255) return null;
      result = (result << 8) + n;
    }
    return result;
  }
}
