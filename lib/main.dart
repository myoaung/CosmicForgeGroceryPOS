import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/auth_gate.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'core/services/backup_service.dart';
import 'dart:async';
import 'core/database/local_database.dart';
import 'core/providers/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const urlFromDefine =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const keyFromDefine =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  var supabaseUrl = urlFromDefine;
  var supabaseAnonKey = keyFromDefine;

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      await dotenv.load(fileName: '.env.example');
    }
    supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }

  if (supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseAnonKey != 'your_anon_key_here') {
    if (!supabaseUrl.toLowerCase().startsWith('https://')) {
      throw StateError('SUPABASE_URL must use HTTPS/TLS.');
    }
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } else {
    debugPrint('Supabase is not configured. Running in offline/local mode.');
  }

  // 4. Create Database & Automated Backup (P0-3)
  // We initialize the DB here to run the Safe Backup (VACUUM INTO)
  // before the UI starts, ensuring data safety.
  final db = LocalDatabase();
  await _runDailyBackup(db);
  _startRecurringBackups(db);

  // 5. Run the app wrapped in a ProviderScope for Riverpod
  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
    ],
    child: const MyApp(),
  ));
}

void _startRecurringBackups(LocalDatabase db) {
  // Runs every 12 hours to ensure backups even without app restart.
  Timer.periodic(const Duration(hours: 12), (_) async {
    try {
      await _runDailyBackup(db);
    } catch (e) {
      debugPrint('BackupService scheduled error: $e');
    }
  });
}

Future<void> _runDailyBackup(LocalDatabase db) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    final lastBackup = prefs.getString('last_backup_date');

    if (lastBackup != today) {
      debugPrint('BackupService: Starting daily backup...');
      final backupService = BackupService();
      await backupService.backupDatabase(db);
      await backupService.pruneOldBackups();

      await prefs.setString('last_backup_date', today);
      debugPrint('BackupService: Daily backup completed for $today');
    } else {
      debugPrint('BackupService: Backup already performed today.');
    }
  } catch (e) {
    debugPrint('BackupService (Main) Error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosmic Forge Grocery POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Pyidaungsu', // Standard for Myanmar font support
      ),
      home: const AuthGate(),
    );
  }
}
