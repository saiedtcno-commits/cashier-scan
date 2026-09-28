import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/product.dart';
import '../providers/app_providers.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final Product? product;
  final String? initialBarcode;

  const ProductFormScreen({
    super.key,
    this.product,
    this.initialBarcode,
  });

  @override
  ConsumerState<ProductFormScreen> createState() =>
      _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  late final TextEditingController barcode;
  late final TextEditingController name;
  late final TextEditingController price;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    barcode = TextEditingController(
      text: widget.product?.barcode ??
          widget.initialBarcode ??
          '',
    );

    name = TextEditingController(
      text: widget.product?.name ?? '',
    );

    price = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
  }

  @override
  void dispose() {
    barcode.dispose();
    name.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> scanBarcode() async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const _BarcodePicker(),
      ),
    );

    if (value != null && mounted) {
      barcode.text = value;
    }
  }

  Future<void> save() async {
    final b = barcode.text.trim();
    final n = name.text.trim();

    final p = double.tryParse(
      price.text.trim().replaceAll(',', '.'),
    );

    if (b.isEmpty || n.isEmpty || p == null || p < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'برجاء إدخال الباركود والاسم والسعر بشكل صحيح',
          ),
        ),
      );

      return;
    }

    setState(() => saving = true);

    try {
      final db = ref.read(databaseProvider);

      if (widget.product == null) {
        // منتج جديد
        await db.insertProduct(
          Product(
            barcode: b,
            name: n,
            price: p,
            quantity: 0,
          ),
        );
      } else {
        // تعديل منتج موجود
        // copyWith يحافظ على كمية المخزون الحالية.
        await db.updateProduct(
          widget.product!.copyWith(
            barcode: b,
            name: n,
            price: p,
          ),
        );
      }

      ref.invalidate(productsProvider);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لا يمكن حفظ المنتج: الباركود مستخدم بالفعل',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'تعديل المنتج' : 'إضافة منتج',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: barcode,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'الباركود',
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: scanBarcode,
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'اسم المنتج',
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: const InputDecoration(
              labelText: 'السعر',
              suffixText: 'ج.م',
            ),
          ),

          // عرض المخزون الحالي عند تعديل المنتج
          if (isEditing) ...[
            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'المخزون الحالي',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${widget.product!.quantity}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'يتم تعديل المخزون من خلال إدارة المخزون.',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],

          const SizedBox(height: 28),

          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: saving ? null : save,
              icon: const Icon(Icons.save),
              label: Text(
                saving ? 'جاري الحفظ...' : 'حفظ',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodePicker extends StatefulWidget {
  const _BarcodePicker();

  @override
  State<_BarcodePicker> createState() => _BarcodePickerState();
}

class _BarcodePickerState extends State<_BarcodePicker> {
  final controller = MobileScannerController(
    detectionTimeoutMs: 250,
  );

  bool done = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح الباركود'),
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (done) return;

          final value = capture.barcodes.isNotEmpty
              ? capture.barcodes.first.rawValue
              : null;

          if (value != null && value.isNotEmpty) {
            done = true;
            Navigator.pop(context, value);
          }
        },
      ),
    );
  }
}
