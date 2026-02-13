import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/local_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/tax_provider.dart';
import '../../../core/localization/mmk_rounding.dart';
import 'package:uuid/uuid.dart';
import 'package:grocery/core/providers/sync_provider.dart';
import 'package:grocery/core/services/sync_service.dart';

// Model for UI display
class CartEntry {
  final CartItem item;
  final Product product;

  CartEntry({required this.item, required this.product});

  double get totalPrice => product.price * item.quantity;
}

class CartState {
  final List<CartEntry> items;
  final double subtotal;
  final double taxAmount;
  final double total;

  CartState({
    this.items = const [],
    this.subtotal = 0.0,
    this.taxAmount = 0.0,
    this.total = 0.0,
  });

  CartState copyWith({
    List<CartEntry>? items,
    double? subtotal,
    double? taxAmount,
    double? total,
  }) {
    return CartState(
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
    );
  }
}

// ... (imports)

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final db = ref.watch(databaseProvider);
  final taxRate = ref.watch(taxRateProvider);
  final syncService = ref.watch(syncServiceProvider);
  return CartNotifier(db, taxRate, syncService);
});

class CartNotifier extends StateNotifier<CartState> {
  final LocalDatabase _db;
  final double _taxRate;
  final SyncService _syncService;

  CartNotifier(this._db, this._taxRate, this._syncService) : super(CartState()) {
    _loadCart();
  }

  // ... (existing code handles loadCart etc)

  Future<void> checkout(String storeId, String tenantId) async {
    if (state.items.isEmpty) return;
    
    // ... (transaction creation logic same as before)
    final transactionId = const Uuid().v4();
    final now = DateTime.now();

    await _db.into(_db.transactions).insert(
      TransactionsCompanion.insert(
        id: transactionId,
        storeId: storeId,
        tenantId: tenantId,
        subtotal: state.subtotal,
        taxAmount: state.taxAmount,
        totalAmount: state.total,
        timestamp: now,
        isSynced: const drift.Value(false),
      ),
    );

    for (var entry in state.items) {
      await _db.into(_db.transactionItems).insert(
        TransactionItemsCompanion.insert(
          transactionId: transactionId,
          productId: entry.product.id,
          productName: entry.product.name,
          quantity: entry.item.quantity,
          unitPrice: entry.product.price,
          taxAmount: entry.product.isTaxExempt ? 0.0 : (entry.totalPrice * (_taxRate / 100)),
        ),
      );
    }

    await clearCart();
    
    // 4. Trigger Sync (Fire & Forget)
    _syncService.syncPendingTransactions(); 
  }

  Future<void> _loadCart() async {
    final query = _db.select(_db.cartItems).join([
      drift.innerJoin(_db.products, _db.products.id.equalsExp(_db.cartItems.productId))
    ]);

    final result = await query.get();
    
    final entries = result.map((row) {
      return CartEntry(
        item: row.readTable(_db.cartItems),
        product: row.readTable(_db.products),
      );
    }).toList();

    _calculateTotals(entries);
  }

  void _calculateTotals(List<CartEntry> entries) {
    double subtotal = 0.0;
    double taxAmount = 0.0;

    for (var entry in entries) {
      final lineTotal = entry.totalPrice;
      subtotal += lineTotal;

      if (!entry.product.isTaxExempt) {
        taxAmount += lineTotal * (_taxRate / 100);
      }
    }

    // Round tax or total? Usually total is rounded.
    // Let's assume subtotal + tax = rawTotal.
    // Then round rawTotal using MMK rounding.
    final rawTotal = subtotal + taxAmount;
    final roundedTotal = rawTotal.roundMm; 

    state = CartState(
      items: entries,
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: roundedTotal.toDouble(),
    );
  }

  Future<void> addToCart(Product product) async {
    // Check if item exists
    final existingItem = state.items.firstWhere(
      (e) => e.product.id == product.id,
      orElse: () => CartEntry(item: CartItem(id: -1, productId: '', quantity: 0), product: product), // Dummy
    );

    if (existingItem.item.id != -1) {
      // Update quantity
      final newQuantity = existingItem.item.quantity + 1;
      await (_db.update(_db.cartItems)..where((t) => t.id.equals(existingItem.item.id))).write(
        CartItemsCompanion(quantity: drift.Value(newQuantity)),
      );
    } else {
      // Insert new
      await _db.into(_db.cartItems).insert(
        CartItemsCompanion(
          productId: drift.Value(product.id),
          quantity: const drift.Value(1),
        ),
      );
    }
    await _loadCart();
  }

  Future<void> removeFromCart(CartItem item) async {
    if (item.quantity > 1) {
       await (_db.update(_db.cartItems)..where((t) => t.id.equals(item.id))).write(
        CartItemsCompanion(quantity: drift.Value(item.quantity - 1)),
      );
    } else {
      await (_db.delete(_db.cartItems)..where((t) => t.id.equals(item.id))).go();
    }
    await _loadCart();
  }

  Future<void> clearCart() async {
    await _db.delete(_db.cartItems).go();
    await _loadCart();
  }
  
  // Method to refresh if tax rate changes (since constructor injection captures initial value, 
  // but ref.watch usually recreates notifier or just updates... Wait. 
  // StateNotifierProvider(ref.watch(tax)) will recreate the notifier when tax changes.
  // That's good reactivity, but reloading DB every tax change might be slightly inefficient but acceptable.
}
