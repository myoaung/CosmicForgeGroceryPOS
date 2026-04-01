import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/session_context.dart';

final sessionContextProvider = StreamProvider<SessionContext>((ref) async* {
  try {
    final client = Supabase.instance.client;
    yield SessionContext.fromSupabaseSession(client.auth.currentSession);

    yield* client.auth.onAuthStateChange.map(
      (event) => SessionContext.fromSupabaseSession(event.session),
    );
  } catch (_) {
    yield SessionContext.unauthenticated();
  }
});

final isAdminSessionProvider = Provider<bool>((ref) {
  final context = ref.watch(sessionContextProvider).valueOrNull;
  if (context == null) return false;
  if (!context.isAuthenticated || context.isExpired) return false;
  return context.isAdmin;
});

final isAuthenticatedSessionProvider = Provider<bool>((ref) {
  final context = ref.watch(sessionContextProvider).valueOrNull;
  if (context == null) return false;
  return context.isAuthenticated && !context.isExpired;
});
