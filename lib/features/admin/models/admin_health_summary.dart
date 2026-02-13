class AdminHealthSummary {
  final String tenantId;
  final String businessName; // Maps to 'business_name' from SQL View
  final DateTime lastSync;
  final double storageUsageMb;

  AdminHealthSummary({
    required this.tenantId,
    required this.businessName,
    required this.lastSync,
    required this.storageUsageMb,
  });

  factory AdminHealthSummary.fromJson(Map<String, dynamic> json) {
    return AdminHealthSummary(
      tenantId: json['tenant_id'] as String,
      // Handle potential null or missing 'business_name' gracefully, 
      // but prefer 'business_name' as requested.
      businessName: json['business_name'] as String? ?? 'Unknown Business', 
      lastSync: DateTime.tryParse(json['last_sync'] as String? ?? '') ?? DateTime.now(),
      storageUsageMb: (json['storage_usage_mb'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
