import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/local_database.dart';

final databaseProvider = Provider<LocalDatabase>((ref) {
  return LocalDatabase();
});
