import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/repositories/cart_repository.dart';
import '../../../core/providers/tax_provider.dart';
import '../../../core/localization/mmk_rounding.dart';
import 'package:grocery/core/providers/sync_provider.dart';
import 'package:grocery/core/services/sync_service.dart';
import '../../../core/usecases/checkout_use_case.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/database/local_database.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/auth/session_context.dart';
import '../../../core/providers/session_provider.dart';

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
  final cartRepo = DriftCartRepository(db);
  final checkoutUseCase = CheckoutUseCase(db);
  final taxRate = ref.watch(taxRateProvider);
  final syncService = ref.watch(syncServiceProvider);
  final scope = ref.watch(activeTenantStoreScopeProvider);
  // Session context is sourced from the JWT-backed provider — never from the UI.
  final sessionContext = ref.watch(sessionContextProvider).valueOrNull;
  return CartNotifier(
    cartRepo,
    checkoutUseCase,
    taxRate,
    syncService,
    tenantId: scope?.tenantId,
    storeId: scope?.storeId,
    sessionContext: sessionContext,
  );
});

class CartNotifier extends StateNotifier<CartState> {
  final CartRepository _cartRepo;
  final CheckoutUseCase _checkout;
  final double _taxRate;
  final SyncService _syncService;
  final String? _tenantId;
  final String? _storeId;
  // Session context is injected at construction — sourced from the JWT provider.
  // This is the single authoritative source of tenant/store identity for checkout.
  final SessionContext? _sessionContext;

  CartNotifier(
    this._cartRepo,
    this._checkout,
    this._taxRate,
    this._syncService, {
    String? tenantId,
    String? storeId,
    SessionContext? sessionContext,
  })  : _tenantId = tenantId,
        _storeId = storeId,
        _sessionContext = sessionContext,
        super(CartState()) {
    _loadCart();
  }

  // ... (existing code handles loadCart etc)

  /// Processes checkout using the session context injected at construction.
  ///
  /// Does NOT accept storeId/tenantId parameters — the session is the only
  /// authoritative source. Throws a [StateError] if the session is absent,
  /// expired, or missing tenant/store claims.
  Future<void> checkout() async {
    if (state.items.isEmpty) return;

    final session = _sessionContext;
    if (session == null) {
      throw StateError(
          'CartNotifier: no session context available. '
          'Ensure the user is signed in before checkout.');
    }
    // Delegate all remaining session validation to CheckoutUseCase.
    await _checkout.execute(
      session: session,
      items: state.items,
      subtotal: state.subtotal,
      taxAmount: state.taxAmount,
      totalAmount: state.total,
      taxRate: _taxRate,
    );
    await _loadCart();

    // Trigger Sync (Fire & Forget)
    _syncService.syncPendingTransactions();
  }

  Future<void> _loadCart() async {
    final entries = await _cartRepo.loadEntries(
      tenantId: _tenantId,
      storeId: _storeId,
    );
    if (!mounted) return;
    _calculateTotals(entries
        .map((e) => CartEntry(item: e.item, product: e.product))
        .toList());
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

  Future<void> addToCart(
    Product product, {
    required String tenantId,
    String? storeId,
  }) async {
    // Check if item exists
    final existingItem = state.items.firstWhere(
      (e) => e.product.id == product.id,
      orElse: () => CartEntry(
          item: CartItem(
            id: -1,
            tenantId: tenantId,
            storeId: storeId,
            productId: '',
            quantity: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isDirty: true,
            syncStatus: 'pending',
            lastSyncedAt: null,
          ),
          product: product),
    );

    if (existingItem.item.id != -1) {
      // Update quantity
      final newQuantity = existingItem.item.quantity + 1;
      await _cartRepo.updateQuantity(
        existingItem.item.id,
        newQuantity,
        tenantId: tenantId,
        storeId: storeId,
      );
    } else {
      await _cartRepo.addProduct(
        product.id,
        tenantId: tenantId,
        storeId: storeId,
      );
    }
    await _loadCart();
  }

  Future<void> removeFromCart(CartItem item) async {
    if (item.quantity > 1) {
      await _cartRepo.updateQuantity(
        item.id,
        item.quantity - 1,
        tenantId: item.tenantId,
        storeId: item.storeId,
      );
    } else {
      await _cartRepo.deleteItem(
        item.id,
        tenantId: item.tenantId,
        storeId: item.storeId,
      );
    }
    await _loadCart();
  }

  Future<void> clearCart() async {
    await _cartRepo.clear(
      tenantId: _tenantId,
      storeId: _storeId,
    );
    await _loadCart();
  }

  // Method to refresh if tax rate changes (since constructor injection captures initial value,
  // but ref.watch usually recreates notifier or just updates... Wait.
  // StateNotifierProvider(ref.watch(tax)) will recreate the notifier when tax changes.
  // That's good reactivity, but reloading DB every tax change might be slightly inefficient but acceptable.
}
