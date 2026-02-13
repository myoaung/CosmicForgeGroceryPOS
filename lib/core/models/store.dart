class Store {
  final String id;
  final String tenantId;
  final String storeName;
  final String currencyCode;
  final double taxRate;
  final bool isGeofenceEnabled;
  final String? authorizedBssid;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  Store({
    required this.id,
    required this.tenantId,
    required this.storeName,
    required this.currencyCode,
    required this.taxRate,
    required this.isGeofenceEnabled,
    this.authorizedBssid,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      storeName: json['store_name'] as String,
      currencyCode: json['currency_code'] as String? ?? 'MMK',
      taxRate: (json['tax_rate'] as num?)?.toDouble() ?? 5.0,
      isGeofenceEnabled: json['is_geofence_enabled'] as bool? ?? true,
      authorizedBssid: json['authorized_bssid'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'store_name': storeName,
      'currency_code': currencyCode,
      'tax_rate': taxRate,
      'is_geofence_enabled': isGeofenceEnabled,
      'authorized_bssid': authorizedBssid,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Store copyWith({
    double? taxRate,
  }) {
    return Store(
      id: id,
      tenantId: tenantId,
      storeName: storeName,
      currencyCode: currencyCode,
      taxRate: taxRate ?? this.taxRate,
      isGeofenceEnabled: isGeofenceEnabled,
      authorizedBssid: authorizedBssid,
      latitude: latitude,
      longitude: longitude,
      createdAt: createdAt,
    );
  }
}
