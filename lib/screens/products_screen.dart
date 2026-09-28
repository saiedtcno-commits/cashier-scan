import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../providers/app_providers.dart';
import '../widgets/price_text.dart';
import 'product_form_screen.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});
  @override ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}
class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final search = TextEditingController();
  String query = '';
  @override void dispose() { search.dispose(); super.dispose(); }
  Future<void> delete(Product p) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('حذف المنتج'), content: Text('هل تريد حذف «${p.name}»؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف'))],
    ));
    if (ok == true) { await ref.read(databaseProvider).deleteProduct(p.id!); ref.invalidate(productsProvider); }
  }
  @override Widget build(BuildContext context) {
    final products = ref.watch(productsProvider(query));
    return Scaffold(
      appBar: AppBar(title: const Text('المنتجات')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen())); ref.invalidate(productsProvider); }, icon: const Icon(Icons.add), label: const Text('إضافة')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: TextField(controller: search, onChanged: (v) => setState(() => query = v), decoration: InputDecoration(hintText: 'ابحث بالاسم أو الباركود', prefixIcon: const Icon(Icons.search), suffixIcon: query.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () { search.clear(); setState(() => query = ''); })) )),
        Expanded(child: products.when(data: (items) => items.isEmpty ? const Center(child: Text('لا توجد منتجات')) : ListView.separated(padding: const EdgeInsets.all(12), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) { final p = items[i]; return Card(child: ListTile(title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(p.barcode), trailing: Row(mainAxisSize: MainAxisSize.min, children: [PriceText(p.price), PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: p))); else await delete(p); ref.invalidate(productsProvider); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('تعديل')), PopupMenuItem(value: 'delete', child: Text('حذف'))])]))); }), loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Center(child: Text('حدث خطأ: $e')))),
      ]),
    );
  }
}
