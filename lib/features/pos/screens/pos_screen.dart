import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocery/core/database/local_database.dart';
import 'package:grocery/core/providers/database_provider.dart';
import 'package:grocery/features/pos/providers/cart_provider.dart';

class POSLayout extends ConsumerWidget {
  const POSLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final database = ref.watch(databaseProvider);

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
                  child: TextField(decoration: InputDecoration(hintText: 'Search Products...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder())),
                ),
                Expanded(
                  child: StreamBuilder<List<Product>>(
                    stream: database.select(database.products).watch(), // Watch all products
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final products = snapshot.data!;
                      return GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return Card(
                            elevation: 2,
                            child: InkWell(
                              onTap: () {
                                ref.read(cartProvider.notifier).addToCart(product);
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.shopping_bag, size: 40, color: Colors.blueGrey),
                                  const SizedBox(height: 8),
                                  Text(product.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('${product.price} MMK', style: const TextStyle(color: Colors.green)),
                                  if (product.isTaxExempt) 
                                    const Chip(label: Text('Tax Exempt', style: TextStyle(fontSize: 10)), visualDensity: VisualDensity.compact),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                // Seed Button for Debugging
                ElevatedButton(
                  onPressed: () async {
                    // Seed dummy products
                    await database.into(database.products).insertOnConflictUpdate(
                      ProductsCompanion.insert(
                        id: 'p1', 
                        name: 'Rice (1 Bag)', 
                        price: 50000, 
                        isTaxExempt: const drift.Value(true), 
                        unitType: 'UNIT'
                      )
                    );
                    await database.into(database.products).insertOnConflictUpdate(
                      ProductsCompanion.insert(
                        id: 'p2', 
                        name: 'Cooking Oil (1L)', 
                        price: 8000, 
                        isTaxExempt: const drift.Value(true), 
                        unitType: 'UNIT' // Liquid usually UNIT or WEIGHT?
                      )
                    );
                    await database.into(database.products).insertOnConflictUpdate(
                      ProductsCompanion.insert(
                        id: 'p3', 
                        name: 'Beer (Can)', 
                        price: 2500, 
                        isTaxExempt: const drift.Value(false), 
                        unitType: 'UNIT'
                      )
                    );
                  }, 
                  child: const Text('Seed Dummy Products')
                ),
              ],
            ),
          ),
          // Right: Cart
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Current Order', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: cartState.items.length,
                      itemBuilder: (context, index) {
                        final entry = cartState.items[index];
                        return ListTile(
                          title: Text(entry.product.name),
                          subtitle: Text('${entry.item.quantity} x ${entry.product.price}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${entry.totalPrice}'),
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () {
                                  ref.read(cartProvider.notifier).removeFromCart(entry.item);
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
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:'), Text('${cartState.subtotal}')]),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Tax:'), Text('${cartState.taxAmount}')]),
                        const Divider(),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text('Total:', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          Text('${cartState.total}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ]),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                            child: const Text('PAY & PRINT'),
                            onPressed: () async {
                              // Finalize Transaction
                              // 1. Security Check
                              try {
                                final storeService = ref.read(storeServiceProvider);
                                final isSecure = await storeService.validateSecurity();
                                
                                if (!context.mounted) return;

                                if (!isSecure) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Security Alert: Transaction Blocked! Device is outside store geofence.'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    )
                                  );
                                  return;
                                }

                                // 2. Process Payment (Mock)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Transaction Complete! Total: ${cartState.total} MMK'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  )
                                );

                                // 3. Clear Cart & Save to DB (Persistence handled by CartNotifier state usually, but clearing)
                                // await ref.read(cartProvider.notifier).clearCart();
                                // NEW: Checkout (Save Transaction & Sync)
                                final storeId = ref.read(storeServiceProvider).activeStore?.id ?? 'unknown_store';
                                final tenantId = ref.read(storeServiceProvider).activeStore?.tenantId ?? 'unknown_tenant';
                                
                                await ref.read(cartProvider.notifier).checkout(storeId, tenantId);
                                
                              } catch (e) {
                                if (context.mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                }
                              }
                            },
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
