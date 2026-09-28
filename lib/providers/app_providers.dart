import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

final databaseProvider = Provider<AppDatabase>(
  (ref) => AppDatabase.instance,
);

final productsProvider =
    FutureProvider.family<List<Product>, String>((ref, query) {
  return ref.read(databaseProvider).getProducts(query);
});

/// ===============================
/// Cart
/// ===============================

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void add(Product product) {
    final index = state.indexWhere(
      (item) => item.product.barcode == product.barcode,
    );

    if (index >= 0) {
      final updated = [...state];
      updated[index].quantity++;
      state = updated;
    } else {
      state = [
        ...state,
        CartItem(product: product),
      ];
    }
  }

  void increment(String barcode) {
    final index = state.indexWhere(
      (item) => item.product.barcode == barcode,
    );

    if (index < 0) return;

    final updated = [...state];
    updated[index].quantity++;
    state = updated;
  }

  void decrement(String barcode) {
    final index = state.indexWhere(
      (item) => item.product.barcode == barcode,
    );

    if (index < 0) return;

    final updated = [...state];

    if (updated[index].quantity <= 1) {
      updated.removeAt(index);
    } else {
      updated[index].quantity--;
    }

    state = updated;
  }

  void remove(String barcode) {
    state = state
        .where((item) => item.product.barcode != barcode)
        .toList();
  }

  void clear() {
    state = [];
  }
}

final cartProvider =
    NotifierProvider<CartNotifier, List<CartItem>>(
  CartNotifier.new,
);

/// ===============================
/// Cart Total
/// ===============================

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).fold(
        0.0,
        (sum, item) => sum + item.lineTotal,
      );
});

/// ===============================
/// Cart Quantity
/// ===============================

final cartQuantityProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).fold(
        0,
        (sum, item) => sum + item.quantity,
      );
});

/// ===============================
/// Save Invoice
/// ===============================

final saveInvoiceProvider = Provider<Future<String> Function()>((ref) {
  return () async {
    final cart = ref.read(cartProvider);

    if (cart.isEmpty) {
      throw Exception('السلة فارغة');
    }

    final database = ref.read(databaseProvider);

    final invoiceItems = cart.map((item) {
      final productId = item.product.id;

      if (productId == null) {
        throw Exception(
          'المنتج "${item.product.name}" ليس له رقم تعريف',
        );
      }

      return {
        'product_id': productId,
        'barcode': item.product.barcode,
        'product_name': item.product.name,
        'price': item.product.price,
        'quantity': item.quantity,
        'line_total': item.lineTotal,
      };
    }).toList();

    final invoiceNumber = await database.saveInvoice(
      items: invoiceItems,
      total: ref.read(cartTotalProvider),
    );

    // بعد نجاح البيع فقط يتم تفريغ السلة.
    ref.read(cartProvider.notifier).clear();

    // تحديث قائمة المنتجات حتى تظهر الكميات الجديدة.
    ref.invalidate(productsProvider);

    return invoiceNumber.toString();
  };
});
