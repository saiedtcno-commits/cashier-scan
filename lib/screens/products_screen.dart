import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../providers/app_providers.dart';
import '../widgets/price_text.dart';
import 'product_form_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final search = TextEditingController();

  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> delete(Product product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text(
          'هل تريد حذف «${product.name}»؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (ok == true && product.id != null) {
      await ref
          .read(databaseProvider)
          .deleteProduct(product.id!);

      ref.invalidate(productsProvider);
    }
  }

  Future<void> openAddProduct() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProductFormScreen(),
      ),
    );

    ref.invalidate(productsProvider);
  }

  Future<void> openEditProduct(Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          product: product,
        ),
      ),
    );

    ref.invalidate(productsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(
      productsProvider(query),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: openAddProduct,
        icon: const Icon(Icons.add),
        label: const Text('إضافة'),
      ),

      body: Column(
        children: [
          // =========================
          // Search
          // =========================

          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              8,
            ),
            child: TextField(
              controller: search,
              onChanged: (value) {
                setState(() {
                  query = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الباركود',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          search.clear();

                          setState(() {
                            query = '';
                          });
                        },
                      ),
              ),
            ),
          ),

          // =========================
          // Products
          // =========================

          Expanded(
            child: products.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('لا توجد منتجات'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),

                  itemBuilder: (_, index) {
                    final product = items[index];

                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),

                        // =========================
                        // Product name
                        // =========================

                        title: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        // =========================
                        // Barcode + Stock
                        // =========================

                        subtitle: Padding(
                          padding: const EdgeInsets.only(
                            top: 6,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.barcode,
                              ),

                              const SizedBox(height: 5),

                              Row(
                                children: [
                                  const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 16,
                                  ),

                                  const SizedBox(width: 5),

                                  Text(
                                    'المخزون: ${product.quantity}',
                                    style: TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                      color: product.quantity <= 0
                                          ? Colors.red
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // =========================
                        // Price + Menu
                        // =========================

                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PriceText(product.price),

                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await openEditProduct(product);
                                } else if (value == 'delete') {
                                  await delete(product);
                                }
                              },

                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('تعديل'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('حذف'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },

              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),

              error: (error, _) => Center(
                child: Text(
                  'حدث خطأ: $error',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
