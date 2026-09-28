import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../providers/app_providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);

    try {
      final products = await ref
          .read(databaseProvider)
          .getProducts(_searchController.text.trim());

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      _showMessage(
        'حدث خطأ أثناء تحميل المنتجات',
        isError: true,
      );
    }
  }

  Future<void> _showStockDialog(
    Product product, {
    required bool isAdding,
  }) async {
    final quantityController = TextEditingController();
    final noteController = TextEditingController();

    final quantity = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isAdding ? 'إضافة للمخزون' : 'خصم من المخزون',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'المخزون الحالي: ${_formatQuantity(product.quantity)}',
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'الكمية',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة',
                  hintText: 'مثال: توريد جديد / تالف / تسوية',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(
                  quantityController.text.trim(),
                );

                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('أدخل كمية صحيحة'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context, value);
              },
              child: Text(isAdding ? 'إضافة' : 'خصم'),
            ),
          ],
        );
      },
    );

    final note = noteController.text.trim();

    quantityController.dispose();
    noteController.dispose();

    if (quantity == null) return;

    await _changeStock(
      product,
      quantity,
      isAdding: isAdding,
      note: note,
    );
  }

  Future<void> _changeStock(
    Product product,
    double quantity, {
    required bool isAdding,
    required String note,
  }) async {
    try {
      final db = ref.read(databaseProvider);

      if (product.id == null) {
        _showMessage(
          'المنتج غير صالح',
          isError: true,
        );
        return;
      }

      if (isAdding) {
        await db.addStock(
  productId: product.id!,
  quantity: quantity,
  note: note,
);
      } else {
        await db.removeStock(
  productId: product.id!,
  quantity: quantity,
  note: note,
);
      }

      await _loadProducts();

      ref.invalidate(productsProvider);

      if (!mounted) return;

      _showMessage(
        isAdding
            ? 'تمت إضافة الكمية للمخزون'
            : 'تم خصم الكمية من المخزون',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _showMovements(Product product) async {
    if (product.id == null) return;

    try {
      final movements = await ref
    .read(databaseProvider)
    .getStockMovements(
      productId: product.id!,
    );

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          product.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'سجل حركات المخزون',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: movements.isEmpty
                        ? const Center(
                            child: Text(
                              'لا توجد حركات للمخزون',
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: movements.length,
                            separatorBuilder: (_, __) =>
                                const Divider(),
                            itemBuilder: (context, index) {
                              final movement = movements[index];

                              final type =
                                  movement['type'] as String? ?? '';

                              final quantity =
                                  (movement['quantity'] as num?)
                                      ?.toDouble() ??
                                  0;

                              final note =
                                  movement['note'] as String? ?? '';

                              final createdAt =
                                  movement['created_at'] as String? ??
                                  '';

                              final isIn = type == 'IN';

                              return ListTile(
                                leading: CircleAvatar(
                                  child: Icon(
                                    isIn
                                        ? Icons.add
                                        : Icons.remove,
                                  ),
                                ),
                                title: Text(
                                  isIn
                                      ? 'إضافة مخزون'
                                      : 'خصم من المخزون',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    if (note.isNotEmpty)
                                      Text(note),
                                    if (createdAt.isNotEmpty)
                                      Text(
                                        _formatDate(createdAt),
                                        style: TextStyle(
                                          color:
                                              Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: Text(
                                  '${isIn ? '+' : '-'}${_formatQuantity(quantity)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isIn
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'تعذر تحميل سجل المخزون',
        isError: true,
      );
    }
  }

  String _formatQuantity(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value).toLocal();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المخزون'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _loadProducts(),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم المنتج أو الباركود',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadProducts();
                            setState(() {});
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _products.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد منتجات',
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadProducts,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              20,
                            ),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];

                              final isOutOfStock =
                                  product.quantity <= 0;

                              return Card(
                                margin:
                                    const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            child: Icon(
                                              Icons.inventory_2,
                                              color: isOutOfStock
                                                  ? Colors.red
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment
                                                      .start,
                                              children: [
                                                Text(
                                                  product.name,
                                                  style:
                                                      const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 17,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'باركود: ${product.barcode}',
                                                  style: TextStyle(
                                                    color: Colors
                                                        .grey
                                                        .shade600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                _formatQuantity(
                                                  product.quantity,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  color: isOutOfStock
                                                      ? Colors.red
                                                      : Colors.green,
                                                ),
                                              ),
                                              Text(
                                                'المخزون',
                                                style: TextStyle(
                                                  color: Colors
                                                      .grey
                                                      .shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: FilledButton.icon(
                                              onPressed: () =>
                                                  _showStockDialog(
                                                product,
                                                isAdding: true,
                                              ),
                                              icon: const Icon(
                                                Icons.add,
                                              ),
                                              label: const Text(
                                                'إضافة',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed:
                                                  product.quantity > 0
                                                      ? () =>
                                                          _showStockDialog(
                                                            product,
                                                            isAdding:
                                                                false,
                                                          )
                                                      : null,
                                              icon: const Icon(
                                                Icons.remove,
                                              ),
                                              label: const Text(
                                                'خصم',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 6),

                                      SizedBox(
                                        width: double.infinity,
                                        child: TextButton.icon(
                                          onPressed: () =>
                                              _showMovements(product),
                                          icon: const Icon(
                                            Icons.history,
                                          ),
                                          label: const Text(
                                            'سجل حركات المخزون',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
