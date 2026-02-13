import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sync_service.dart';
import 'database_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(databaseProvider);
  SupabaseClient? client;
  try {
    client = Supabase.instance.client;
  } catch (_) {
    // Not initialized
  }
  return SyncService(db, client); 
});
