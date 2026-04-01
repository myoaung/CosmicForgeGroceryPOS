import 'package:drift/drift.dart';

import 'database_connection.dart';

part 'local_database.g.dart';

@TableIndex(name: 'products_updated_at_idx', columns: {#updatedAt})
@TableIndex(name: 'products_is_dirty_idx', columns: {#isDirty})
@TableIndex(name: 'products_sync_status_idx', columns: {#syncStatus})
class Products extends Table {
  TextColumn get id => text()(); // UUID from Supabase
  TextColumn get tenantId => text().withDefault(const Constant('unknown_tenant'))();
  TextColumn get storeId => text().nullable()();
  TextColumn get name => text()();
  RealColumn get price => real()();
  RealColumn get stock => real().withDefault(const Constant(0.0))();
  BoolColumn get isTaxExempt => boolean().withDefault(const Constant(false))();
  TextColumn get unitType => text()(); // 'UNIT' or 'WEIGHT'
  TextColumn get imagePath => text().nullable()(); // Local file path
  TextColumn get imageUrl => text().nullable()(); // Cloud URL
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'cart_items_updated_at_idx', columns: {#updatedAt})
@TableIndex(name: 'cart_items_is_dirty_idx', columns: {#isDirty})
class CartItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tenantId => text().withDefault(const Constant('unknown_tenant'))();
  TextColumn get storeId => text().nullable()();
  TextColumn get productId => text().references(Products, #id)();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

@TableIndex(name: 'transactions_updated_at_idx', columns: {#updatedAt})
@TableIndex(name: 'transactions_is_dirty_idx', columns: {#isDirty})
@TableIndex(name: 'transactions_sync_status_idx', columns: {#syncStatus})
class Transactions extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get storeId => text()();
  TextColumn get tenantId => text()();
  RealColumn get subtotal => real()();
  RealColumn get taxAmount => real()();
  RealColumn get totalAmount => real()();
  DateTimeColumn get timestamp => dateTime()(); // business time
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'transaction_items_updated_at_idx', columns: {#updatedAt})
@TableIndex(name: 'transaction_items_is_dirty_idx', columns: {#isDirty})
class TransactionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tenantId => text().withDefault(const Constant('unknown_tenant'))();
  TextColumn get storeId => text().nullable()();
  TextColumn get transactionId => text().references(Transactions, #id)();
  TextColumn get productId => text()(); // Snapshot, not reference, in case product deleted
  TextColumn get productName => text()(); // Snapshot
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()(); // Snapshot
  RealColumn get taxAmount => real()(); // Snapshot
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDirty => boolean().withDefault(const Constant(true))();
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
}

@TableIndex(name: 'sync_queue_status_idx', columns: {#status})
@TableIndex(name: 'sync_queue_next_attempt_idx', columns: {#nextAttemptAt})
@TableIndex(name: 'sync_queue_entity_idx', columns: {#entityType, #entityId})
class SyncQueues extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tenantId => text()();
  TextColumn get storeId => text().nullable()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // INSERT, UPDATE, DELETE
  TextColumn get payload => text()(); // JSON payload
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get deviceId => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();
}

@DriftDatabase(tables: [Products, CartItems, Transactions, TransactionItems, SyncQueues])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  LocalDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 6; // sync queue + enterprise retry metadata

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 3) {
            await m.addColumn(products, products.stock);
            await m.addColumn(products, products.createdAt);
            await m.addColumn(products, products.isDirty);
            await m.addColumn(products, products.syncStatus);
            await m.addColumn(products, products.lastSyncedAt);
          }
          if (from < 4) {
            await m.addColumn(cartItems, cartItems.createdAt);
            await m.addColumn(cartItems, cartItems.updatedAt);
            await m.addColumn(cartItems, cartItems.isDirty);
            await m.addColumn(cartItems, cartItems.syncStatus);
            await m.addColumn(cartItems, cartItems.lastSyncedAt);

            await m.addColumn(transactions, transactions.createdAt);
            await m.addColumn(transactions, transactions.updatedAt);
            await m.addColumn(transactions, transactions.isDirty);
            await m.addColumn(transactions, transactions.syncStatus);
            await m.addColumn(transactions, transactions.lastSyncedAt);

            await m.addColumn(transactionItems, transactionItems.createdAt);
            await m.addColumn(transactionItems, transactionItems.updatedAt);
            await m.addColumn(transactionItems, transactionItems.isDirty);
            await m.addColumn(transactionItems, transactionItems.syncStatus);
            await m.addColumn(transactionItems, transactionItems.lastSyncedAt);
          }
          if (from < 6) {
            await m.addColumn(products, products.tenantId);
            await m.addColumn(products, products.storeId);
            await m.addColumn(cartItems, cartItems.tenantId);
            await m.addColumn(cartItems, cartItems.storeId);
            await m.addColumn(transactionItems, transactionItems.tenantId);
            await m.addColumn(transactionItems, transactionItems.storeId);
            await m.createTable(syncQueues);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async => openDatabaseConnection());
}
