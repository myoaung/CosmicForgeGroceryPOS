import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../database/local_database.dart';
import '../sync/sync_queue_worker.dart';
import '../services/sync_service.dart';

/// Domain-level draft used by UI/Controllers. Keeps UI free of Drift imports.
class ProductDraft {
  final String? id;
  final String tenantId;
  final String? storeId;
  final String name;
  final double price;
  final String unitType;
  final bool isTaxExempt;
  final String? imagePath;
  final String? imageUrl;
  final double? stock;
  final DateTime? createdAt;

  const ProductDraft({
    this.id,
    // tenantId is required — always source this from SessionContext.tenantId.
    // Never supply a hardcoded string; that would corrupt local data and fail
    // RLS on sync to Supabase.
    required this.tenantId,
    this.storeId,
    required this.name,
    required this.price,
    required this.unitType,
    required this.isTaxExempt,
    this.imagePath,
    this.imageUrl,
    this.stock,
    this.createdAt,
  });
}

abstract class ProductRepository {
  Stream<List<Product>> watchAll({required String tenantId, String? storeId});
  Future<List<Product>> fetchPaginated({required String tenantId, String? storeId, int limit = 50, int offset = 0});
  Future<void> upsert(ProductDraft draft);
  Future<void> delete(String id, {required String tenantId, String? storeId});
}

class DriftProductRepository implements ProductRepository {
  final LocalDatabase db;
  final SyncService? _syncService;

  DriftProductRepository(this.db, {SyncService? syncService})
      : _syncService = syncService;

  @override
  Stream<List<Product>> watchAll({required String tenantId, String? storeId}) {
    final query = db.select(db.products)
      ..where((p) => p.tenantId.equals(tenantId));
    if (storeId != null && storeId.isNotEmpty) {
      query.where((p) => p.storeId.equals(storeId));
    }
    return query.watch();
  }

  @override
  Future<List<Product>> fetchPaginated({required String tenantId, String? storeId, int limit = 50, int offset = 0}) async {
    final query = db.select(db.products)
      ..where((p) => p.tenantId.equals(tenantId));
    if (storeId != null && storeId.isNotEmpty) {
      query.where((p) => p.storeId.equals(storeId));
    }
    query.limit(limit, offset: offset);
    return query.get();
  }

  @override
  Future<void> upsert(ProductDraft draft) async {
    final now = DateTime.now();
    final id = draft.id ?? const Uuid().v4();

    await db.into(db.products).insertOnConflictUpdate(
          ProductsCompanion(
            id: drift.Value(id),
            tenantId: drift.Value(draft.tenantId),
            storeId: drift.Value(draft.storeId),
            name: drift.Value(draft.name),
            price: drift.Value(draft.price),
            unitType: drift.Value(draft.unitType),
            isTaxExempt: drift.Value(draft.isTaxExempt),
            imagePath: drift.Value(draft.imagePath),
            imageUrl: drift.Value(draft.imageUrl),
            stock: drift.Value(draft.stock ?? 0),
            createdAt: drift.Value(draft.createdAt ?? now),
            updatedAt: drift.Value(now),
            isDirty: const drift.Value(true),
            syncStatus: const drift.Value('pending'),
          ),
        );

    if (_syncService != null) {
      await _syncService.enqueueChange(
        tenantId: draft.tenantId,
        storeId: draft.storeId,
        entityType: 'products',
        entityId: id,
        operation:
            draft.id == null ? SyncOperation.insert : SyncOperation.update,
        payload: {
          'id': id,
          'tenant_id': draft.tenantId,
          'store_id': draft.storeId,
          'name': draft.name,
          'price': draft.price,
          'unit_type': draft.unitType,
          'is_tax_exempt': draft.isTaxExempt,
          'image_url': draft.imageUrl,
          'updated_at': now.toIso8601String(),
          'created_at': (draft.createdAt ?? now).toIso8601String(),
          'version': 1,
        },
      );
    }
  }

  @override
  Future<void> delete(String id,
      {required String tenantId, String? storeId}) async {
    final selectQuery = db.select(db.products)
      ..where((t) => t.id.equals(id))
      ..where((t) => t.tenantId.equals(tenantId));
    if (storeId != null && storeId.isNotEmpty) {
      selectQuery.where((t) => t.storeId.equals(storeId));
    }
    final product = await selectQuery.getSingleOrNull();

    final deleteQuery = db.delete(db.products)
      ..where((t) => t.id.equals(id))
      ..where((t) => t.tenantId.equals(tenantId));
    if (storeId != null && storeId.isNotEmpty) {
      deleteQuery.where((t) => t.storeId.equals(storeId));
    }
    await deleteQuery.go();

    if (_syncService != null) {
      final resolvedTenantId = product?.tenantId ?? tenantId;
      final resolvedStoreId = product?.storeId ?? storeId;
      await _syncService.enqueueChange(
        tenantId: resolvedTenantId,
        storeId: resolvedStoreId,
        entityType: 'products',
        entityId: id,
        operation: SyncOperation.delete,
        payload: {
          'id': id,
          'updated_at': DateTime.now().toIso8601String(),
          'version': (product?.updatedAt.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch),
        },
      );
    }
  }
}
