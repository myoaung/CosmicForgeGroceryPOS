import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_database.dart';
import 'package:drift/drift.dart' as drift;
import 'dart:io';
import 'supabase_storage_service.dart';

import 'dart:async';

class SyncService {
  final LocalDatabase _db;
  final SupabaseClient? _supabase;
  Timer? _syncTimer;

  SyncService(this._db, this._supabase) {
    // Fallback for offline mode: specific polling or trigger on actions.
    // connectivity_plus requires symlinks which failed.
    // We will poll every 60 seconds to check for pending items.
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      syncPendingTransactions();
    });
  }

  Future<void> syncPendingTransactions() async {
    if (_supabase == null) {
      print('SyncService: Supabase not initialized. Skipping sync.');
      return;
    }

    // 1. Fetch pending transactions
    final pendingTransactions = await (_db.select(_db.transactions)
      ..where((t) => t.isSynced.equals(false)))
      .get();

    if (pendingTransactions.isEmpty) return;

    print('SyncService: Found ${pendingTransactions.length} pending transactions.');

    for (var transaction in pendingTransactions) {
      try {
        // 2. Fetch related items
        final items = await (_db.select(_db.transactionItems)
          ..where((t) => t.transactionId.equals(transaction.id)))
          .get();

        // 3. Push to Supabase
        // Supabase Transaction (Postgres)
        await _supabase.from('transactions').insert({
          'id': transaction.id,
          'store_id': transaction.storeId,
          'tenant_id': transaction.tenantId,
          'subtotal': transaction.subtotal,
          'tax_amount': transaction.taxAmount,
          'total_amount': transaction.totalAmount,
          'timestamp': transaction.timestamp.toIso8601String(),
          // 'synced_at': DateTime.now().toIso8601String(), // Optional: if server tracks this
        });

        // Push items
        if (items.isNotEmpty) {
          final itemsPayload = items.map((item) => {
            'transaction_id': item.transactionId,
            'product_id': item.productId,
            'product_name': item.productName,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'tax_amount': item.taxAmount,
          }).toList();

          await _supabase.from('transaction_items').insert(itemsPayload);
        }

        // 4. Mark as Synced Local
        await (_db.update(_db.transactions)..where((t) => t.id.equals(transaction.id)))
            .write(const TransactionsCompanion(isSynced: drift.Value(true)));

        print('SyncService: Synced Transaction ${transaction.id}');

      } catch (e) {
        print('SyncService Error for ${transaction.id}: $e');
        // Continue to next transaction, verified strictly.
      }
    }
  }
  Future<void> uploadPendingImages(String tenantId) async {
    if (_supabase == null) return;

    // 1. Fetch products needing upload (local path exists, cloud url null)
    final pendingProducts = await (_db.select(_db.products)
      ..where((p) => p.imagePath.isNotNull() & p.imageUrl.isNull()))
      .get();

    if (pendingProducts.isEmpty) return;

    print('SyncService: Found ${pendingProducts.length} pending image uploads.');

    // We need storage service. 
    // Ideally injected, but for now we create it here or assume imports
    final storage = SupabaseStorageService(_supabase!);

    for (var product in pendingProducts) {
      final file = File(product.imagePath!);
      if (!file.existsSync()) {
        print('SyncService: File not found for ${product.name} at ${product.imagePath}');
        continue;
      }

      try {
        print('SyncService: Uploading image for ${product.name}...');
        final url = await storage.uploadProductImage(
          imageFile: file, 
          tenantId: tenantId, 
          productId: product.id
        );

        if (url != null) {
          // Update DB
          await (_db.update(_db.products)..where((p) => p.id.equals(product.id)))
            .write(ProductsCompanion(imageUrl: drift.Value(url)));
            
          print('SyncService: Uploaded image for ${product.name}');
          
          // Optional: Audit log here or assume UI did it? 
          // If background sync, we should probably log it too.
          // But StoreService isn't available here easily. Skipping audit for background sync for now.
        }
      } catch (e) {
        print('SyncService: Image upload failed for ${product.id}: $e');
      }
    }
  }


  /// Syncs products with Supabase using Last Write Wins strategy based on updated_at.
  Future<void> syncProducts(String tenantId) async {
    if (_supabase == null) return;

    try {
      // 1. Fetch Cloud Products (newer than last sync? For now, fetch all or paginated)
      // Optimization: In real app, store 'last_sync_timestamp' locally and only fetch > that.
      // Here, we'll fetch all active products for the tenant to ensure consistency for now.
      final response = await _supabase!.from('products')
          .select()
          .eq('tenant_id', tenantId); // Assuming RLS or filter
      
      final cloudProductsData = response as List<dynamic>;
      
      for (var cloudJson in cloudProductsData) {
        final cloudId = cloudJson['id'] as String;
        final cloudUpdatedAt = DateTime.parse(cloudJson['updated_at'] as String);
        
        // Check local
        final localProduct = await (_db.select(_db.products)..where((p) => p.id.equals(cloudId))).getSingleOrNull();
        
        if (localProduct == null) {
          // Insert Local
          await _db.into(_db.products).insert(
            ProductsCompanion.insert(
              id: cloudId,
              name: cloudJson['name'],
              price: (cloudJson['price'] as num).toDouble(),
              unitType: cloudJson['unit_type'] ?? 'UNIT',
              isTaxExempt: drift.Value(cloudJson['is_tax_exempt'] ?? false),
              imageUrl: drift.Value(cloudJson['image_url']),
              updatedAt: drift.Value(cloudUpdatedAt),
            )
          );
        } else {
          // Conflict Resolution: Last Write Wins
          final localUpdatedAt = localProduct.updatedAt;
          
          if (localUpdatedAt == null || cloudUpdatedAt.isAfter(localUpdatedAt)) {
            // Cloud is newer -> Overwrite Local
            await (_db.update(_db.products)..where((p) => p.id.equals(cloudId))).write(
              ProductsCompanion(
                name: drift.Value(cloudJson['name']),
                price: drift.Value((cloudJson['price'] as num).toDouble()),
                unitType: drift.Value(cloudJson['unit_type'] ?? 'UNIT'),
                isTaxExempt: drift.Value(cloudJson['is_tax_exempt'] ?? false),
                imageUrl: drift.Value(cloudJson['image_url']),
                updatedAt: drift.Value(cloudUpdatedAt),
              )
            );
            print('SyncService: Updated local product $cloudId from cloud.');
          } else {
             // Local is newer OR Equal
             
             // Field-Level Merge: If remote has a cloud_url but local doesn't, preserve the cloud_url
             // User Request: "if localData.imageUrl == null && remoteData.imageUrl != null ... updateProduct"
             if (localProduct.imageUrl == null && cloudJson['image_url'] != null) {
                 final cloudUrl = cloudJson['image_url'] as String;
                 
                 // Update Local DB to have this URL
                 await (_db.update(_db.products)..where((p) => p.id.equals(cloudId))).write(
                   ProductsCompanion(imageUrl: drift.Value(cloudUrl))
                 );
                 print('SyncService: Merged cloud URL into local product $cloudId.');
                 
                 // Prepare to push (if local is strictly newer) with the merged URL
                 // If equal, we don't need to push, but we updated local key.
             }

             if (localUpdatedAt.isAfter(cloudUpdatedAt)) {
               // Push Local to Cloud
               // Note: If we just merged the URL above, we should include it in the push.
               // We need to re-read or construct the object.
               final productToPush = (localProduct.imageUrl == null && cloudJson['image_url'] != null)
                   ? localProduct.copyWith(imageUrl: drift.Value(cloudJson['image_url'] as String))
                   : localProduct;

               await _pushProductToCloud(productToPush, tenantId);
             }
          }
        }
      }

      // 2. Push Local Changes (that might not exist in cloud yet)
      // Fetch local products where updatedAt is newer than some threshold or just iterate
      // Simple approach: Push all dirty records? We don't have a 'dirty' flag, relying on updatedAt comparison above
      // But what about new local products not in cloud list?
      
      final allLocalProducts = await _db.select(_db.products).get();
      final cloudIds = cloudProductsData.map((e) => e['id'] as String).toSet();
      
      for (var local in allLocalProducts) {
        if (!cloudIds.contains(local.id)) {
           // New local product, push to cloud
           await _pushProductToCloud(local, tenantId);
        }
      }
      
    } catch (e) {
      print('SyncService: syncProducts error: $e');
    }
  }

  Future<void> _pushProductToCloud(Product product, String tenantId) async {
    if (_supabase == null) return;
    try {
      await _supabase!.from('products').upsert({
        'id': product.id,
        'tenant_id': tenantId,
        'name': product.name,
        'price': product.price,
        'unit_type': product.unitType,
        'is_tax_exempt': product.isTaxExempt,
        'image_url': product.imageUrl,
        'updated_at': product.updatedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      });
      print('SyncService: Pushed local product ${product.id} to cloud.');
    } catch (e) {
      print('SyncService: Failed to push product ${product.id}: $e');
    }
  }
}

