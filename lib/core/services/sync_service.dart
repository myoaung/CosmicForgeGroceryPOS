import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:supabase_flutter/supabase_flutter.dart';


import '../database/local_database.dart';
import 'supabase_storage_service.dart';
import '../sync/sync_queue_worker.dart';
import 'observability_service.dart';

abstract class SyncGateway {
  Future<void> upsertTransaction(Map<String, dynamic> payload);
  Future<void> upsertTransactionItems(List<Map<String, dynamic>> payload);
  Future<void> upsertProduct(Map<String, dynamic> payload);
}

class ConflictException implements Exception {
  final String message;
  ConflictException(this.message);
  @override
  String toString() => 'ConflictException: $message';
}

class SupabaseSyncGateway implements SyncGateway {
  final SupabaseClient _client;
  SupabaseSyncGateway(this._client);

  @override
  Future<void> upsertTransaction(Map<String, dynamic> payload) async {
    await _client.from('transactions').upsert(payload);
  }

  @override
  Future<void> upsertTransactionItems(List<Map<String, dynamic>> payload) async {
    if (payload.isNotEmpty) {
      await _client.from('transaction_items').upsert(payload);
    }
  }

  @override
  Future<void> upsertProduct(Map<String, dynamic> payload) async {
    await _client.from('products').upsert(payload);
  }
}

class SyncService {
  final LocalDatabase _db;
  final SupabaseClient? _supabase;
  final SyncGateway? _gateway;
  final SyncQueueWorker _queueWorker;
  final ObservabilityService _obs = const ObservabilityService();
  Timer? _pollingTimer;

  SyncService(this._db, this._supabase, [SyncGateway? gateway])
      : _gateway = gateway ?? (_supabase != null ? SupabaseSyncGateway(_supabase) : null),
        _queueWorker = SyncQueueWorker(_db, _supabase) {
    _obs.recordEvent('sync_service_started');
    // Poll for pending items every 60 seconds.
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      syncPendingTransactions();
      processSyncQueue();
    });
  }

  void dispose() {
    _pollingTimer?.cancel();
    _queueWorker.stopScheduledProcessing();
  }

  Future<void> enqueueChange({
    required String tenantId,
    required String? storeId,
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
    int version = 1,
    String? deviceId,
  }) {
    return _queueWorker.enqueue(
      tenantId: tenantId,
      storeId: storeId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      version: version,
      deviceId: deviceId,
    );
  }

  Future<void> processSyncQueue({
    int batchSize = 50,
    ConflictStrategy strategy = ConflictStrategy.lastWriteWins,
  }) {
    return _queueWorker.processQueue(batchSize: batchSize, conflictStrategy: strategy);
  }

  Future<void> onNetworkReconnected() => processSyncQueue();

  Future<void> manualSyncNow() async {
    await syncPendingTransactions();
    await processSyncQueue();
  }

  Future<void> syncPendingTransactions() async {
    if (_gateway == null) {
      _obs.recordEvent('sync_skipped', metadata: {'reason': 'Supabase not initialized'});
      _obs.incrementMetric('sync.skipped');
      return;
    }

    final pendingTransactions = await (_db.select(_db.transactions)
      ..where((t) => t.syncStatus.isNotIn(['synced'])))
      .get();

    if (pendingTransactions.isEmpty) return;

    for (var transaction in pendingTransactions) {
      final start = DateTime.now();
      try {
        final items = await (_db.select(_db.transactionItems)
          ..where((t) => t.transactionId.equals(transaction.id)))
          .get();

        await _gateway.upsertTransaction({
          'id': transaction.id,
          'store_id': transaction.storeId,
          'tenant_id': transaction.tenantId,
          'subtotal': transaction.subtotal,
          'tax_amount': transaction.taxAmount,
          'total_amount': transaction.totalAmount,
          'timestamp': transaction.timestamp.toIso8601String(),
          'updated_at': transaction.updatedAt.toIso8601String(),
        });

        if (items.isNotEmpty) {
          final itemsPayload = items.map((item) {
            final tenantId = item.tenantId;
            final storeId = item.storeId;
            return {
              'transaction_id': item.transactionId,
              'product_id': item.productId,
              'product_name': item.productName,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'tax_amount': item.taxAmount,
              'updated_at': item.updatedAt.toIso8601String(),
              'tenant_id': tenantId,
              'store_id': storeId,
            };
          }).toList();

          await _gateway.upsertTransactionItems(itemsPayload);
        }

        await (_db.update(_db.transactions)..where((t) => t.id.equals(transaction.id))).write(
          TransactionsCompanion(
            isDirty: const drift.Value(false),
            syncStatus: const drift.Value('synced'),
            lastSyncedAt: drift.Value(DateTime.now()),
          ),
        );
        _obs.incrementMetric('sync.success');
        _obs.recordLatency('sync.transaction.latency', DateTime.now().difference(start));
      } catch (e) {
        final status = e is ConflictException ? 'conflict' : 'error';
        await (_db.update(_db.transactions)..where((t) => t.id.equals(transaction.id))).write(
          TransactionsCompanion(
            syncStatus: drift.Value(status),
            isDirty: const drift.Value(true),
          ),
        );
        // replaced debugPrint with obs recordEvent below
        _obs.incrementMetric('sync.failure', labels: {'status': status});
        _obs.recordEvent('sync_error', metadata: {
          'transaction_id': transaction.id,
          'status': status,
          'error': e.toString(),
        });
      }
    }
  }

  Future<void> uploadPendingImages(String tenantId) async {
    if (_supabase == null) return;

    final pendingProducts = await (_db.select(_db.products)
      ..where((p) => p.imagePath.isNotNull() & p.imageUrl.isNull()))
      .get();

    if (pendingProducts.isEmpty) return;

    final storage = SupabaseStorageService(_supabase);

    for (var product in pendingProducts) {
      final file = File(product.imagePath!);
      if (!file.existsSync()) {
        _obs.recordEvent('sync_image_not_found', metadata: {
          'product': product.name,
          'path': product.imagePath.toString()
        });
        continue;
      }

      try {
        final url = await storage.uploadProductImage(
          imageFile: file, 
          tenantId: tenantId, 
          productId: product.id
        );

        if (url != null) {
          await (_db.update(_db.products)..where((p) => p.id.equals(product.id)))
            .write(ProductsCompanion(
              imageUrl: drift.Value(url),
              isDirty: const drift.Value(true),
              syncStatus: const drift.Value('pending'),
              updatedAt: drift.Value(DateTime.now()),
            ));
        }
      } catch (e) {
      _obs.recordEvent('sync_image_upload_failed', metadata: {
        'product_id': product.id,
        'error': e.toString(),
      });
      }
    }
  }

  /// Syncs products with Supabase using Last Write Wins strategy based on updated_at.
  Future<void> syncProducts(String tenantId) async {
    if (_gateway == null || _supabase == null) return;

    try {
      final response = await _supabase.from('products')
          .select()
          .eq('tenant_id', tenantId);
      
      final cloudProductsData = response as List<dynamic>;
      
      for (var cloudJson in cloudProductsData) {
        final cloudId = cloudJson['id'] as String;
        final cloudUpdatedAt = DateTime.parse(cloudJson['updated_at'] as String);
        
        final localProduct = await (_db.select(_db.products)..where((p) => p.id.equals(cloudId))).getSingleOrNull();
        
        if (localProduct == null) {
          await _db.into(_db.products).insert(
            ProductsCompanion.insert(
              id: cloudId,
              name: cloudJson['name'],
              price: (cloudJson['price'] as num).toDouble(),
              stock: drift.Value((cloudJson['stock'] as num?)?.toDouble() ?? 0),
              unitType: cloudJson['unit_type'] ?? 'UNIT',
              isTaxExempt: drift.Value(cloudJson['is_tax_exempt'] ?? false),
              imageUrl: drift.Value(cloudJson['image_url']),
              updatedAt: drift.Value(cloudUpdatedAt),
              createdAt: drift.Value(DateTime.parse(cloudJson['created_at'] as String)),
              isDirty: const drift.Value(false),
              syncStatus: const drift.Value('synced'),
              lastSyncedAt: drift.Value(DateTime.now()),
            )
          );
        } else {
          final localUpdatedAt = localProduct.updatedAt;
          
          if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
            await (_db.update(_db.products)..where((p) => p.id.equals(cloudId))).write(
              ProductsCompanion(
                name: drift.Value(cloudJson['name']),
                price: drift.Value((cloudJson['price'] as num).toDouble()),
                stock: drift.Value((cloudJson['stock'] as num?)?.toDouble() ?? localProduct.stock),
                unitType: drift.Value(cloudJson['unit_type'] ?? 'UNIT'),
                isTaxExempt: drift.Value(cloudJson['is_tax_exempt'] ?? false),
                imageUrl: drift.Value(cloudJson['image_url']),
                updatedAt: drift.Value(cloudUpdatedAt),
                isDirty: const drift.Value(false),
                syncStatus: const drift.Value('synced'),
                lastSyncedAt: drift.Value(DateTime.now()),
              )
            );
          } else if (localUpdatedAt.isAfter(cloudUpdatedAt)) {
            await _gateway.upsertProduct(_mapProduct(localProduct, tenantId));
            await (_db.update(_db.products)..where((p) => p.id.equals(cloudId))).write(
              ProductsCompanion(
                isDirty: const drift.Value(false),
                syncStatus: const drift.Value('synced'),
                lastSyncedAt: drift.Value(DateTime.now()),
              ),
            );
          } else if (localProduct.imageUrl == null && cloudJson['image_url'] != null) {
            await (_db.update(_db.products)..where((p) => p.id.equals(cloudId))).write(
              ProductsCompanion(
                imageUrl: drift.Value(cloudJson['image_url']),
                isDirty: const drift.Value(false),
                syncStatus: const drift.Value('synced'),
                lastSyncedAt: drift.Value(DateTime.now()),
              ),
            );
          }
        }
      }

      final allLocalProducts = await _db.select(_db.products).get();
      final cloudIds = cloudProductsData.map((e) => e['id'] as String).toSet();
      
      for (var local in allLocalProducts) {
        if (!cloudIds.contains(local.id) && local.syncStatus != 'synced') {
           await _gateway.upsertProduct(_mapProduct(local, tenantId));
           await (_db.update(_db.products)..where((p) => p.id.equals(local.id))).write(
             ProductsCompanion(
               isDirty: const drift.Value(false),
               syncStatus: const drift.Value('synced'),
               lastSyncedAt: drift.Value(DateTime.now()),
             ),
           );
        }
      }
      
    } catch (e) {
      _obs.recordEvent('sync_products_error', metadata: {'error': e.toString()});
    }
  }

  Map<String, dynamic> _mapProduct(Product product, String tenantId) {
    final storeId = product.storeId;
    return {
      'id': product.id,
      'tenant_id': tenantId,
      'store_id': storeId,
      'name': product.name,
      'price': product.price,
      'stock': product.stock,
      'unit_type': product.unitType,
      'is_tax_exempt': product.isTaxExempt,
      'image_url': product.imageUrl,
      'updated_at': product.updatedAt.toIso8601String(),
      'created_at': product.createdAt.toIso8601String(),
    };
  }
}

