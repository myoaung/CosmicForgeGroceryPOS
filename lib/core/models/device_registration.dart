class DeviceRegistration {
  final String? id;
  final String deviceId;
  final String tenantId;
  final String storeId;
  final String? deviceName;
  final String? bssid;
  final String? ipRange;
  final String status;
  final DateTime registeredAt;

  const DeviceRegistration({
    this.id,
    required this.deviceId,
    required this.tenantId,
    required this.storeId,
    this.deviceName,
    this.bssid,
    this.ipRange,
    this.status = 'active',
    required this.registeredAt,
  });

  bool get isActive => status.toLowerCase() == 'active';
}
