import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/session_provider.dart';
import '../dashboard/dashboard_screen.dart';
import 'auth_provider.dart';
import 'login_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authBootstrapProvider);
    final sessionAsync = ref.watch(sessionContextProvider);

    return sessionAsync.when(
      data: (session) {
        if (!session.isAuthenticated || session.isExpired) {
          return const LoginScreen();
        }
        return const DashboardScreen();
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const LoginScreen(),
    );
  }
}
