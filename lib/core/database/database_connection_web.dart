// ignore_for_file: deprecated_member_use

import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openDatabaseConnection() {
  return WebDatabase.withStorage(
    DriftWebStorage.indexedDb('cosmic_forge_pos'),
    logStatements: false,
  );
}
