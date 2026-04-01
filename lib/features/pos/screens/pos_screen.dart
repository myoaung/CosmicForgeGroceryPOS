import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery/features/pos/providers/cart_provider.dart';
import 'package:grocery/core/providers/store_provider.dart';
import 'package:grocery/features/products/providers/product_provider.dart';

import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart' as isp;
import 'package:grocery/core/database/local_database.dart';

class POSLayout extends ConsumerStatefulWidget {
  const POSLayout({super.key});

  @override
  ConsumerState<POSLayout> createState() => _POSLayoutState();
}

class _POSLayoutState extends ConsumerState<POSLayout> {
  static const _pageSize = 50;
  late final isp.PagingController<int, Product> _pagingController;

  @override
  void initState() {
    super.initState();
    _pagingController = isp.PagingController<int, Product>(
      fetchPage: (int pageKey) => _fetchPage(pageKey),
      getNextPageKey: (state) {
        final totalItems = state.pages?.expand((page) => page).length ?? 0;
        final latestPageSize = state.pages?.lastOrNull?.length ?? 0;
        if (latestPageSize < _pageSize) {
          return null; // No more pages
        }
        return totalItems; // Use the total items as the offset for the next page
      },
    );
  }

  Future<List<Product>> _fetchPage(int pageKey) async {
    return ref.read(
      paginatedProductsProvider((limit: _pageSize, offset: pageKey)).future,
    );
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = ref.watch(activeTenantStoreScopeProvider);

    return Row(
      children: [
        // Left: Product Grid
        Expanded(
          flex: 2,
          child: Column(
            children: [
              // Search Bar placeholder
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: TextField(
                    decoration: InputDecoration(
                        hintText: 'Search Products...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder())),
              ),
              Expanded(
                child: ValueListenableBuilder<isp.PagingState<int, Product>>(
                  valueListenable: _pagingController,
                  builder: (context, state, child) {
                    return isp.PagedGridView<int, Product>(
                      padding: const EdgeInsets.all(8),
                      state: state,
                      fetchNextPage: _pagingController.fetchNextPage,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      builderDelegate: isp.PagedChildBuilderDelegate<Product>(
                        itemBuilder: (context, product, index) {
                      return Card(
                        elevation: 2,
                        child: InkWell(
                          onTap: () {
                            final tenantId = scope?.tenantId;
                            if (tenantId == null || tenantId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Sign in with a tenant-scoped session before adding items.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            ref.read(cartProvider.notifier).addToCart(
                                  product,
                                  tenantId: tenantId,
                                  storeId: scope?.storeId,
                                );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shopping_bag,
                                  size: 40, color: Colors.blueGrey),
                              const SizedBox(height: 8),
                              Text(product.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text('${product.price} MMK',
                                  style: const TextStyle(color: Colors.green)),
                              if (product.isTaxExempt)
                                const Chip(
                                    label: Text('Tax Exempt',
                                        style: TextStyle(fontSize: 10)),
                                    visualDensity: VisualDensity.compact),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
              // Seed Button removed for production
            ],
          ),
        ),
        // Right: Cart
        Expanded(
          flex: 1,
          child: Container(
            color: Colors.grey[100],
            child: Consumer(
              builder: (context, ref, child) {
                final cartState = ref.watch(cartProvider);
                return Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Current Order',
                          style:
                              TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: cartState.items.length,
                        itemBuilder: (context, index) {
                          final entry = cartState.items[index];
                          return ListTile(
                            title: Text(entry.product.name),
                            subtitle: Text(
                                '${entry.item.quantity} x ${entry.product.price}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${entry.totalPrice}'),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle,
                                      color: Colors.red),
                                  onPressed: () {
                                    ref
                                        .read(cartProvider.notifier)
                                        .removeFromCart(entry.item);
                                  },
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal:'),
                                Text('${cartState.subtotal}')
                              ]),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tax:'),
                                Text('${cartState.taxAmount}')
                              ]),
                          const Divider(),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total:',
                                    style: TextStyle(
                                        fontSize: 24, fontWeight: FontWeight.bold)),
                                Text('${cartState.total}',
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue)),
                              ]),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white),
                              child: const Text('PAY & PRINT'),
                              onPressed: () async {
                                // Finalize Transaction
                                // 1. Security Check
                                try {
                                  final storeService =
                                      ref.read(storeServiceProvider);
                                  final isSecure =
                                      await storeService.validateSecurity();
    
                                  if (!context.mounted) return;
    
                                  if (!isSecure) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text(
                                          'Security Alert: Transaction Blocked! Device is outside store geofence.'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ));
                                    return;
                                  }
    
                                  // 2. Process Payment (Mock)
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(
                                        'Transaction Complete! Total: ${cartState.total} MMK'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ));
                                  // 3. Clear Cart & Save to DB (Persistence handled by CartNotifier state usually, but clearing)
                                  await ref
                                      .read(cartProvider.notifier)
                                      .checkout();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Error: $e')));
                                  }
                                }
                              },
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                );
              }
            ),
          ),
        ),
      ],
    );
  }
}
