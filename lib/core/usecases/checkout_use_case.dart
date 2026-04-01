import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../auth/session_context.dart';
import '../database/local_database.dart';
import '../../features/pos/providers/cart_provider.dart';

class CheckoutUseCase {
  final LocalDatabase db;
  CheckoutUseCase(this.db);

  /// Executes the checkout flow atomically.
  ///
  /// [session] is the caller's current [SessionContext]. The `tenant_id` and
  /// `store_id` written to every local row are derived exclusively from this
  /// object — they are **never** accepted as caller-supplied string parameters.
  /// This is the Dart-layer enforcement of tenant RLS: even if the UI is
  /// compromised, no foreign `tenant_id` can enter the database through this path.
  Future<void> execute({
    required SessionContext session,
    required List<CartEntry> items,
    required double subtotal,
    required double taxAmount,
    required double totalAmount,
    required double taxRate,
  }) async {
    // ── Session guard ──────────────────────────────────────────────────────
    if (!session.isAuthenticated) {
      throw StateError('CheckoutUseCase: session is not authenticated.');
    }
    if (session.isExpired) {
      throw StateError('CheckoutUseCase: session has expired. Please re-login.');
    }
    final tenantId = session.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError(
          'CheckoutUseCase: session has no tenant_id claim. '
          'Ensure the JWT was issued with app_metadata.tenant_id set.');
    }
    // storeId is required for checkout — a store must be active.
    final storeId = session.storeId;
    if (storeId == null || storeId.isEmpty) {
      throw StateError(
          'CheckoutUseCase: session has no store_id claim. '
          'Select and activate a store before checkout.');
    }
    // ──────────────────────────────────────────────────────────────────────

    if (items.isEmpty) return;
    final now = DateTime.now();
    final transactionId = const Uuid().v4();

    await db.transaction(() async {
      // Stock check
      for (final entry in items) {
        final current = await (db.select(db.products)..where((p) => p.id.equals(entry.product.id))).getSingle();
        if (current.stock < entry.item.quantity) {
          throw Exception('Insufficient stock for ${entry.product.name}');
        }
      }

      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: transactionId,
          storeId: storeId,
          tenantId: tenantId,
          subtotal: subtotal,
          taxAmount: taxAmount,
          totalAmount: totalAmount,
          timestamp: now,
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
          isDirty: const drift.Value(true),
          syncStatus: const drift.Value('pending'),
          lastSyncedAt: const drift.Value(null),
        ),
      );

      await db.into(db.syncQueues).insert(
            SyncQueuesCompanion.insert(
              tenantId: tenantId,
              storeId: drift.Value(storeId),
              entityType: 'transactions',
              entityId: transactionId,
              operation: 'INSERT',
              payload: jsonEncode({
                'id': transactionId,
                'tenant_id': tenantId,
                'store_id': storeId,
                'subtotal': subtotal,
                'tax_amount': taxAmount,
                'total_amount': totalAmount,
                'timestamp': now.toIso8601String(),
                'updated_at': now.toIso8601String(),
                'created_at': now.toIso8601String(),
                'version': 1,
              }),
              version: const drift.Value(1),
            ),
          );

      for (final entry in items) {
        await db.into(db.transactionItems).insert(
          TransactionItemsCompanion.insert(
            tenantId: drift.Value(tenantId),
            storeId: drift.Value(storeId),
            transactionId: transactionId,
            productId: entry.product.id,
            productName: entry.product.name,
            quantity: entry.item.quantity,
            unitPrice: entry.product.price,
            taxAmount: entry.product.isTaxExempt ? 0.0 : (entry.product.price * entry.item.quantity * (taxRate / 100)),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
            isDirty: const drift.Value(true),
            syncStatus: const drift.Value('pending'),
            lastSyncedAt: const drift.Value(null),
          ),
        );

        await db.into(db.syncQueues).insert(
              SyncQueuesCompanion.insert(
                tenantId: tenantId,
                storeId: drift.Value(storeId),
                entityType: 'transaction_items',
                entityId: '$transactionId:${entry.product.id}',
                operation: 'INSERT',
                payload: jsonEncode({
                  'id': const Uuid().v4(),
                  'transaction_id': transactionId,
                  'product_id': entry.product.id,
                  'product_name': entry.product.name,
                  'quantity': entry.item.quantity,
                  'unit_price': entry.product.price,
                  'tax_amount': entry.product.isTaxExempt
                      ? 0.0
                      : (entry.product.price * entry.item.quantity * (taxRate / 100)),
                  'tenant_id': tenantId,
                  'store_id': storeId,
                  'updated_at': now.toIso8601String(),
                  'created_at': now.toIso8601String(),
                  'version': 1,
                }),
                version: const drift.Value(1),
              ),
            );

        await (db.update(db.products)..where((p) => p.id.equals(entry.product.id))).write(
          ProductsCompanion(
            stock: drift.Value(entry.product.stock - entry.item.quantity),
            updatedAt: drift.Value(now),
            isDirty: const drift.Value(true),
            syncStatus: const drift.Value('pending'),
          ),
        );

        await db.into(db.syncQueues).insert(
              SyncQueuesCompanion.insert(
                tenantId: tenantId,
                storeId: drift.Value(storeId),
                entityType: 'inventory',
                entityId: entry.product.id,
                operation: 'UPDATE',
                payload: jsonEncode({
                  'id': entry.product.id,
                  'tenant_id': tenantId,
                  'store_id': storeId,
                  'stock': entry.product.stock - entry.item.quantity,
                  'updated_at': now.toIso8601String(),
                  'version': 1,
                }),
                version: const drift.Value(1),
              ),
            );
      }

      await db.delete(db.cartItems).go();
    });
  }
}
