import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/providers/database_provider.dart';
import 'package:grocery/core/providers/store_provider.dart';
import 'package:grocery/core/repositories/product_repository.dart';
import 'package:grocery/core/providers/sync_provider.dart';

final productsProvider = StreamProvider<List<Product>>(
  (ref) {
    final scope = ref.watch(activeTenantStoreScopeProvider);
    if (scope == null) {
      return Stream.value(const <Product>[]);
    }
    return DriftProductRepository(
      ref.watch(databaseProvider),
      syncService: ref.watch(syncServiceProvider),
    ).watchAll(
      tenantId: scope.tenantId,
      storeId: scope.storeId,
    );
  },
);

final paginatedProductsProvider = FutureProvider.family<List<Product>, ({int limit, int offset})>(
  (ref, args) {
    final scope = ref.watch(activeTenantStoreScopeProvider);
    if (scope == null) {
      return Future.value([]);
    }
    return DriftProductRepository(
      ref.watch(databaseProvider),
      syncService: ref.watch(syncServiceProvider),
    ).fetchPaginated(
      tenantId: scope.tenantId,
      storeId: scope.storeId,
      limit: args.limit,
      offset: args.offset,
    );
  },
);

// Provider for Product Actions (CRUD)
final productControllerProvider = Provider((ref) {
  final scope = ref.watch(activeTenantStoreScopeProvider);
  return ProductController(
    DriftProductRepository(
      ref.read(databaseProvider),
      syncService: ref.read(syncServiceProvider),
    ),
    scope,
  );
});

class ProductController {
  final ProductRepository _repo;
  final TenantStoreScope? _scope;

  ProductController(this._repo, this._scope);

  Future<void> upsertProduct(ProductDraft draft) async {
    if (_scope == null) {
      throw StateError('No active tenant/store scope for product update.');
    }
    await _repo.upsert(draft);
  }

  Future<void> deleteProduct(String id) async {
    final scope = _scope;
    if (scope == null) {
      throw StateError('No active tenant/store scope for product delete.');
    }
    await _repo.delete(
      id,
      tenantId: scope.tenantId,
      storeId: scope.storeId,
    );
  }
}
