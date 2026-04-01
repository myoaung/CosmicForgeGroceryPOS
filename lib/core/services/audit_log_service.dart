import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuditLogService {
  AuditLogService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<void> log({
    required String eventType,
    required Map<String, dynamic> eventData,
    String? tenantId,
    String? storeId,
    String? userId,
  }) async {
    final sanitizedData = _sanitize(eventData);

    if (_client == null) {
      debugPrint(
        '[AUDIT][local] event=$eventType tenant=$tenantId store=$storeId user=$userId data=$sanitizedData',
      );
      return;
    }

    try {
      // Use the SECURITY DEFINER RPC so:
      //  - tenant/store/user identity is derived server-side from the JWT
      //  - authenticated users cannot INSERT directly into audit_logs
      //  - created_at is set by the DB (server clock, not device clock)
      await _client.rpc('write_audit_log', params: {
        'p_event_type': eventType,
        'p_event_data': sanitizedData,
      });
    } catch (e) {
      debugPrint('AuditLogService: failed to write audit log: $e');
    }
  }

  Map<String, dynamic> _sanitize(Map<String, dynamic> input) {
    final redactedKeys = <String>{
      'access_token',
      'refresh_token',
      'token',
      'authorization',
      'auth_header',
      'card_number',
      'cvv',
      'payment_info',
      'password',
      'pin',
    };

    final result = <String, dynamic>{};
    input.forEach((key, value) {
      final normalized = key.toLowerCase();
      if (redactedKeys.contains(normalized)) {
        result[key] = '***';
      } else if (value is Map<String, dynamic>) {
        result[key] = _sanitize(value);
      } else {
        result[key] = value;
      }
    });
    return result;
  }
}
