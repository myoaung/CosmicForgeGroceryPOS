import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'local_database.g.dart';

class Products extends Table {
  TextColumn get id => text()(); // UUID from Supabase
  TextColumn get name => text()();
  RealColumn get price => real()();
  BoolColumn get isTaxExempt => boolean().withDefault(const Constant(false))();
  TextColumn get unitType => text()(); // 'UNIT' or 'WEIGHT'
  TextColumn get imagePath => text().nullable()(); // Local file path
  TextColumn get imageUrl => text().nullable()(); // Cloud URL
  DateTimeColumn get updatedAt => dateTime().nullable()(); // For conflict resolution
  
  @override
  Set<Column> get primaryKey => {id};
}

class CartItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
}

class Transactions extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get storeId => text()();
  TextColumn get tenantId => text()();
  RealColumn get subtotal => real()();
  RealColumn get taxAmount => real()();
  RealColumn get totalAmount => real()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get productId => text()(); // Snapshot, not reference, in case product deleted
  TextColumn get productName => text()(); // Snapshot
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()(); // Snapshot
  RealColumn get taxAmount => real()(); // Snapshot
}

@DriftDatabase(tables: [Products, CartItems, Transactions, TransactionItems])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  LocalDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 2; // Bumped for updatedAt

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(products, products.updatedAt);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
