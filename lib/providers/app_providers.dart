import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../models/cart_item.dart';
import '../models/product.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final productsProvider = FutureProvider.family<List<Product>, String>((ref, query) {
  return ref.read(databaseProvider).getProducts(query);
});

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void add(Product product) {
    final index = state.indexWhere((item) => item.product.barcode == product.barcode);
    if (index >= 0) {
      final updated = [...state];
      updated[index].quantity++;
      state = updated;
    } else {
      state = [...state, CartItem(product: product)];
    }
  }

  void increment(String barcode) {
    final index = state.indexWhere((item) => item.product.barcode == barcode);
    if (index < 0) return;
    final updated = [...state];
    updated[index].quantity++;
    state = updated;
  }

  void decrement(String barcode) {
    final index = state.indexWhere((item) => item.product.barcode == barcode);
    if (index < 0) return;
    final updated = [...state];
    if (updated[index].quantity <= 1) {
      updated.removeAt(index);
    } else {
      updated[index].quantity--;
    }
    state = updated;
  }

  void remove(String barcode) => state = state.where((x) => x.product.barcode != barcode).toList();
  void clear() => state = [];
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).fold(0, (sum, item) => sum + item.lineTotal);
});
