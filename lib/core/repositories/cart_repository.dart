import '../database/local_database.dart';
import 'package:drift/drift.dart' as drift;

class CartEntryModel {
  final CartItem item;
  final Product product;
  CartEntryModel(this.item, this.product);
}

abstract class CartRepository {
  Future<List<CartEntryModel>> loadEntries({String? tenantId, String? storeId});
  Future<void> addProduct(String productId,
      {String? tenantId, String? storeId});
  Future<void> updateQuantity(
    int cartItemId,
    double quantity, {
    String? tenantId,
    String? storeId,
  });
  Future<void> deleteItem(int cartItemId, {String? tenantId, String? storeId});
  Future<void> clear({String? tenantId, String? storeId});
}

class DriftCartRepository implements CartRepository {
  final LocalDatabase db;
  DriftCartRepository(this.db);

  @override
  Future<List<CartEntryModel>> loadEntries(
      {String? tenantId, String? storeId}) async {
    final query = db.select(db.cartItems).join([
      drift.innerJoin(
          db.products, db.products.id.equalsExp(db.cartItems.productId))
    ]);
    if (tenantId != null && tenantId.isNotEmpty) {
      query.where(db.cartItems.tenantId.equals(tenantId));
      query.where(db.products.tenantId.equals(tenantId));
    }
    if (storeId != null && storeId.isNotEmpty) {
      query.where(db.cartItems.storeId.equals(storeId));
      query.where(db.products.storeId.equals(storeId));
    }
    final rows = await query.get();
    return rows
        .map((row) => CartEntryModel(
              row.readTable(db.cartItems),
              row.readTable(db.products),
            ))
        .toList();
  }

  @override
  Future<void> addProduct(String productId,
      {String? tenantId, String? storeId}) async {
    await db.into(db.cartItems).insert(
          CartItemsCompanion(
            tenantId: tenantId != null
                ? drift.Value(tenantId)
                : const drift.Value.absent(),
            storeId: drift.Value(storeId),
            productId: drift.Value(productId),
            quantity: const drift.Value(1),
          ),
        );
  }

  @override
  Future<void> updateQuantity(
    int cartItemId,
    double quantity, {
    String? tenantId,
    String? storeId,
  }) async {
    final query = db.update(db.cartItems)
      ..where((t) => t.id.equals(cartItemId));
    if (tenantId != null && tenantId.isNotEmpty) {
      query.where((t) => t.tenantId.equals(tenantId));
    }
    if (storeId != null && storeId.isNotEmpty) {
      query.where((t) => t.storeId.equals(storeId));
    }
    await query.write(
      CartItemsCompanion(quantity: drift.Value(quantity)),
    );
  }

  @override
  Future<void> deleteItem(int cartItemId, {String? tenantId, String? storeId}) {
    final query = db.delete(db.cartItems)
      ..where((t) => t.id.equals(cartItemId));
    if (tenantId != null && tenantId.isNotEmpty) {
      query.where((t) => t.tenantId.equals(tenantId));
    }
    if (storeId != null && storeId.isNotEmpty) {
      query.where((t) => t.storeId.equals(storeId));
    }
    return query.go();
  }

  @override
  Future<void> clear({String? tenantId, String? storeId}) {
    final query = db.delete(db.cartItems);
    if (tenantId != null && tenantId.isNotEmpty) {
      query.where((t) => t.tenantId.equals(tenantId));
    }
    if (storeId != null && storeId.isNotEmpty) {
      query.where((t) => t.storeId.equals(storeId));
    }
    return query.go();
  }
}
