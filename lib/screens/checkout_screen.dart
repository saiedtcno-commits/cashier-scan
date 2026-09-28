import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/app_providers.dart';
import '../models/cart_item.dart';
import '../widgets/price_text.dart';
import 'product_form_screen.dart';
import 'products_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final MobileScannerController scanner;

  String? lastCode;
  DateTime? lastScanAt;

  String? candidateCode;
  int candidateCount = 0;
  DateTime? candidateStartedAt;

  bool isProcessing = false;

  String? notice;
  bool flashGreen = false;

  Timer? flashTimer;
  Timer? candidateResetTimer;

  static const int requiredConfirmations = 2;

  @override
  void initState() {
    super.initState();

    scanner = MobileScannerController(
      // مهم:
      // لا نستخدم noDuplicates لأننا نحتاج رؤية نفس
      // الباركود أكثر من مرة للتأكد منه.
      detectionSpeed: DetectionSpeed.normal,

      detectionTimeoutMs: 250,

      // أهم تعديل:
      // منع الكاميرا من عمل Zoom تلقائي.
      autoZoom: false,

      // باركود المنتجات فقط.
      formats: const [
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
        BarcodeFormat.code128,
      ],
    );
  }

  @override
  void dispose() {
    flashTimer?.cancel();
    candidateResetTimer?.cancel();
    scanner.dispose();
    super.dispose();
  }

  String? _extractBarcode(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) {
      return null;
    }

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();

      if (raw == null || raw.isEmpty) {
        continue;
      }

      final code = raw.replaceAll(RegExp(r'\s+'), '');

      // معظم باركود المنتجات Numeric.
      if (!RegExp(r'^\d+$').hasMatch(code)) {
        continue;
      }

      // أطوال الباركود الشائعة للمنتجات.
      if (code.length != 8 &&
          code.length != 12 &&
          code.length != 13 &&
          code.length != 14) {
        continue;
      }

      return code;
    }

    return null;
  }

  Future<void> handleScan(BarcodeCapture capture) async {
    if (isProcessing) {
      return;
    }

    final code = _extractBarcode(capture);

    if (code == null) {
      return;
    }

    final now = DateTime.now();

    // ---------------------------------------------------------
    // 1. تأكيد القراءة
    // ---------------------------------------------------------

    if (candidateCode == code) {
      candidateCount++;
    } else {
      candidateCode = code;
      candidateCount = 1;
      candidateStartedAt = now;
    }

    // لو القراءة لم تستقر خلال ثانية نبدأ من جديد.
    if (candidateStartedAt != null &&
        now.difference(candidateStartedAt!).inMilliseconds > 1000) {
      candidateCode = code;
      candidateCount = 1;
      candidateStartedAt = now;
    }

    candidateResetTimer?.cancel();

    candidateResetTimer = Timer(
      const Duration(milliseconds: 900),
      () {
        candidateCode = null;
        candidateCount = 0;
        candidateStartedAt = null;
      },
    );

    // ننتظر ظهور نفس الرقم مرتين.
    if (candidateCount < requiredConfirmations) {
      if (mounted) {
        setState(() {
          notice = 'جاري التأكد من الباركود...';
        });
      }

      return;
    }

    // ---------------------------------------------------------
    // 2. منع إضافة نفس المنتج بسرعة مرتين
    // ---------------------------------------------------------

    if (lastCode == code &&
        lastScanAt != null &&
        now.difference(lastScanAt!).inMilliseconds < 1500) {
      return;
    }

    candidateCode = null;
    candidateCount = 0;
    candidateStartedAt = null;

    lastCode = code;
    lastScanAt = now;

    isProcessing = true;

    try {
      // ---------------------------------------------------------
      // 3. البحث في قاعدة البيانات
      // ---------------------------------------------------------

      final product =
          await ref.read(databaseProvider).findByBarcode(code);

      if (!mounted) {
        return;
      }

      // ---------------------------------------------------------
      // 4. المنتج غير موجود
      // ---------------------------------------------------------

      if (product == null) {
        setState(() {
          notice = 'المنتج غير مسجل';
        });

        await HapticFeedback.heavyImpact();

        if (!mounted) {
          return;
        }

        await _showMissingProduct(code);

        return;
      }

      // ---------------------------------------------------------
      // 5. المنتج موجود
      // ---------------------------------------------------------

      ref.read(cartProvider.notifier).add(product);

      await SystemSound.play(SystemSoundType.click);
      await HapticFeedback.lightImpact();

      if (!mounted) {
        return;
      }

      setState(() {
        notice = '${product.name} تمت الإضافة';
        flashGreen = true;
      });

      flashTimer?.cancel();

      flashTimer = Timer(
        const Duration(milliseconds: 220),
        () {
          if (mounted) {
            setState(() {
              flashGreen = false;
            });
          }
        },
      );
    } finally {
      isProcessing = false;
    }
  }

  Future<void> _showMissingProduct(String code) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('المنتج غير مسجل'),
        content: Text(
          'لم يتم العثور على المنتج.\n\n'
          'الباركود:\n$code',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إضافة المنتج'),
          ),
        ],
      ),
    );

    if (go == true && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductFormScreen(
            initialBarcode: code,
          ),
        ),
      );

      ref.invalidate(productsProvider);
    }
  }

  void newInvoice() {
    if (ref.read(cartProvider).isEmpty) {
      return;
    }

    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('فاتورة جديدة'),
        content: const Text(
          'سيتم مسح الفاتورة الحالية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true) {
        ref.read(cartProvider.notifier).clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashier Scan'),
        actions: [
          IconButton(
            tooltip: 'المنتجات',
            icon: const Icon(
              Icons.inventory_2_outlined,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductsScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: Column(
        children: [
          SizedBox(
            height: 245,
            child: Stack(
              children: [
                MobileScanner(
                  controller: scanner,
                  onDetect: handleScan,
                ),

                // منطقة توجيه الباركود.
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 280,
                    height: 115,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 10,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'torch',
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                    onPressed: () => scanner.toggleTorch(),
                    child: const Icon(
                      Icons.flashlight_on,
                    ),
                  ),
                ),

                if (flashGreen)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.green.withOpacity(.22),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (notice != null)
            Container(
              width: double.infinity,
              color: notice == 'المنتج غير مسجل'
                  ? Colors.red.shade700
                  : notice == 'جاري التأكد من الباركود...'
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
              padding: const EdgeInsets.symmetric(
                vertical: 7,
                horizontal: 12,
              ),
              child: Text(
                notice!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 64,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'وجّه الكاميرا إلى الباركود',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      10,
                      8,
                      10,
                      150,
                    ),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 6),
                    itemBuilder: (_, i) => _CartRow(
                      item: cart[i],
                    ),
                  ),
          ),
        ],
      ),

      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            12,
            10,
            12,
            12,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black26,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'الإجمالي',
                      style: TextStyle(fontSize: 15),
                    ),
                    PriceText(
                      total,
                      fontSize: 28,
                      weight: FontWeight.w900,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: newInvoice,
                  icon: const Icon(
                    Icons.receipt_long,
                  ),
                  label: const Text(
                    'فاتورة جديدة',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartRow extends ConsumerWidget {
  final CartItem item;

  const _CartRow({
    required this.item,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Dismissible(
      key: ValueKey(item.product.barcode),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(
          right: 20,
        ),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) {
        ref
            .read(cartProvider.notifier)
            .remove(item.product.barcode);
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    PriceText(
                      item.product.price,
                      fontSize: 13,
                      weight: FontWeight.w500,
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () {
                  ref
                      .read(cartProvider.notifier)
                      .decrement(
                        item.product.barcode,
                      );
                },
                icon: const Icon(
                  Icons.remove_circle_outline,
                ),
              ),

              Text(
                '${item.quantity}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              IconButton(
                onPressed: () {
                  ref
                      .read(cartProvider.notifier)
                      .increment(
                        item.product.barcode,
                      );
                },
                icon: const Icon(
                  Icons.add_circle_outline,
                ),
              ),

              const SizedBox(width: 8),

              PriceText(
                item.lineTotal,
                fontSize: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
