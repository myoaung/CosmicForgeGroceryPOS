import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight web-readiness smoke test. Skips if env vars are not provided.
void main() {
  const supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  group('Web dashboard smoke', () {
    test('supabase connectivity (masked envs)', () async {
      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        return; // CI can skip when secrets not injected.
      }

      final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
      try {
        await client.from('products').select().limit(1).maybeSingle();
      } catch (e) {
        fail('Supabase should respond without auth errors: $e');
      }
    });
  });
}
