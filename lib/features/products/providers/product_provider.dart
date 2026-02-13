
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/providers/database_provider.dart';
import 'package:drift/drift.dart'; // Import drift for Value and Companions

// Provider for getting all products
final productsProvider = StreamProvider<List<Product>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.select(database.products).watch();
});

// Provider for Product Actions (CRUD)
final productControllerProvider = Provider((ref) => ProductController(ref));

class ProductController {
  final Ref _ref;

  ProductController(this._ref);

  Future<void> addProduct(ProductsCompanion product) async {
    final database = _ref.read(databaseProvider);
    await database.into(database.products).insert(product);
  }

  Future<void> updateProduct(ProductsCompanion product) async {
    final database = _ref.read(databaseProvider);
    await database.update(database.products).replace(product);
  }
  
  Future<void> deleteProduct(String id) async {
    final database = _ref.read(databaseProvider);
    await (database.delete(database.products)..where((t) => t.id.equals(id))).go();
  }
}
