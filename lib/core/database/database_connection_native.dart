import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/secure_storage_service.dart';

QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    final secureStorage = SecureStorageService();
    final dbKey = await secureStorage.getOrCreateDatabaseKey();
    final escapedKey = dbKey.replaceAll("'", "''");

    return NativeDatabase.createInBackground(
      file,
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '$escapedKey';");
        rawDb.execute('PRAGMA foreign_keys = ON;');
        rawDb.execute('PRAGMA journal_mode = WAL;');
        rawDb.execute('PRAGMA cipher_memory_security = ON;');

        final cipher = rawDb.select('PRAGMA cipher_version;');
        final cipherVersion = cipher.isEmpty || cipher.first.values.isEmpty
            ? null
            : cipher.first.values.first;
        if (cipherVersion == null || cipherVersion.toString().isEmpty) {
          throw StateError('SQLCipher is required but not available.');
        }
      },
    );
  });
}
