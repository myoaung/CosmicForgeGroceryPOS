import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/device_registration.dart';

class DeviceRegistryService {
  DeviceRegistryService(this._client);

  final SupabaseClient? _client;

  Future<void> registerDevice(DeviceRegistration registration) async {
    if (_client == null) {
      debugPrint(
          'DeviceRegistryService: Supabase unavailable, register skipped.');
      return;
    }

    await _client.from('devices').upsert(
      {
        'id': registration.id,
        'device_id': registration.deviceId,
        'tenant_id': registration.tenantId,
        'store_id': registration.storeId,
        'device_name': registration.deviceName,
        'bssid': registration.bssid,
        'ip_range': registration.ipRange,
        'status': registration.status,
        'registered_at': registration.registeredAt.toIso8601String(),
      },
      onConflict: 'device_id',
    );
  }

  Future<DeviceRegistration?> fetchRegistration(String deviceId) async {
    if (_client == null) return null;

    final row = await _client
        .from('devices')
        .select()
        .eq('device_id', deviceId)
        .maybeSingle();
    if (row == null) return null;

    return DeviceRegistration(
      id: row['id']?.toString(),
      deviceId: row['device_id'] as String,
      tenantId: row['tenant_id'] as String,
      storeId: row['store_id'] as String,
      deviceName: row['device_name'] as String?,
      bssid: row['bssid'] as String?,
      ipRange: row['ip_range'] as String?,
      status: row['status']?.toString() ?? 'active',
      registeredAt: DateTime.tryParse(row['registered_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
