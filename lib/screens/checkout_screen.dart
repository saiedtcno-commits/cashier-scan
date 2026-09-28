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
  bool isSavingInvoice = false;

  String? notice;
  bool flashGreen = false;

  Timer? flashTimer;
  Timer? candidateResetTimer;

  static const int requiredConfirmations = 2;

  @override
  void initState() {
    super.initState();

    scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 250,
      autoZoom: false,
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

      if (!RegExp(r'^\d+$').hasMatch(code)) {
        continue;
      }

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
    if (isProcessing || isSavingInvoice) {
      return;
    }

    final code = _extractBarcode(capture);

    if (code == null) {
      return;
    }

    final now = DateTime.now();

    // ===============================
    // تأكيد قراءة الباركود
    // ===============================

    if (candidateCode == code) {
      candidateCount++;
    } else {
      candidateCode = code;
      candidateCount = 1;
      candidateStartedAt = now;
    }

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

    if (candidateCount < requiredConfirmations) {
      if (mounted) {
        setState(() {
          notice = 'جاري التأكد من الباركود...';
        });
      }

      return;
    }

    // ===============================
    // منع التكرار السريع
    // ===============================

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
      final product =
          await ref.read(databaseProvider).findByBarcode(code);

      if (!mounted) {
        return;
      }

      // ===============================
      // المنتج غير موجود
      // ===============================

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

      // ===============================
      // التحقق من المخزون
      // ===============================

      final cart = ref.read(cartProvider);

      final existingIndex = cart.indexWhere(
        (item) => item.product.barcode == product.barcode,
      );

      final currentCartQuantity =
          existingIndex >= 0 ? cart[existingIndex].quantity : 0;

      if (currentCartQuantity + 1 > product.quantity) {
        setState(() {
          notice = 'الكمية غير متوفرة في المخزون';
        });

        await HapticFeedback.heavyImpact();

        return;
      }

      // ===============================
      // إضافة المنتج للسلة
      // ===============================

      ref.read(cartProvider.notifier).add(product);

      await SystemSound.play(
        SystemSoundType.click,
      );

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
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, true),
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

  // ============================================================
  // إتمام البيع
  // ============================================================

  Future<void> completeSale() async {
    final cart = ref.read(cartProvider);

    if (cart.isEmpty) {
      return;
    }

    final total = ref.read(cartTotalProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إتمام البيع'),
        content: Text(
          'هل تريد حفظ الفاتورة وإتمام البيع؟\n\n'
          'الإجمالي: ${total.toStringAsFixed(2)} ج.م',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: const Text('إتمام البيع'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      isSavingInvoice = true;
      notice = 'جاري حفظ الفاتورة...';
    });

    try {
      final saveInvoice =
          ref.read(saveInvoiceProvider);

      final invoiceNumber = await saveInvoice();

      if (!mounted) {
        return;
      }

      setState(() {
        notice = 'تم حفظ الفاتورة رقم $invoiceNumber';
      });

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم البيع بنجاح'),
          content: Text(
            'رقم الفاتورة:\n$invoiceNumber\n\n'
            'الإجمالي:\n${total.toStringAsFixed(2)} ج.م',
          ),
          actions: [
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text('فاتورة جديدة'),
            ),
          ],
        ),
      );

      if (mounted) {
        setState(() {
          notice = null;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        notice = 'فشل حفظ الفاتورة';
      });

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تعذر إتمام البيع'),
          content: Text(
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
          actions: [
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text('موافق'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSavingInvoice = false;
        });
      }
    }
  }

  // ============================================================
  // فاتورة جديدة / إلغاء الحالية
  // ============================================================

  Future<void> newInvoice() async {
    final cart = ref.read(cartProvider);

    if (cart.isEmpty) {
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('فاتورة جديدة'),
        content: const Text(
          'سيتم إلغاء الفاتورة الحالية ومسح المنتجات منها.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      ref.read(cartProvider.notifier).clear();

      setState(() {
        notice = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final cartQuantity = ref.watch(cartQuantityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashier Scan'),
        actions: [
          IconButton(
            tooltip: 'المنتجات',
            icon: const Icon(
              Icons.inventory_2_outlined,
            ),
            onPressed: isSavingInvoice
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ProductsScreen(),
                      ),
                    );
                  },
          ),
        ],
      ),

      body: Column(
        children: [
          // ======================================================
          // Scanner
          // ======================================================

          SizedBox(
            height: 245,
            child: Stack(
              children: [
                MobileScanner(
                  controller: scanner,
                  onDetect: handleScan,
                ),

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
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 10,
                  right: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'torch',
                    backgroundColor:
                        Colors.black54,
                    foregroundColor: Colors.white,
                    onPressed: isSavingInvoice
                        ? null
                        : () =>
                            scanner.toggleTorch(),
                    child: const Icon(
                      Icons.flashlight_on,
                    ),
                  ),
                ),

                if (flashGreen)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.green
                            .withOpacity(.22),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ======================================================
          // Notice
          // ======================================================

          if (notice != null)
            Container(
              width: double.infinity,
              color: notice ==
                      'المنتج غير مسجل'
                  ? Colors.red.shade700
                  : notice ==
                          'جاري التأكد من الباركود...'
                      ? Colors.orange.shade700
                      : notice ==
                              'فشل حفظ الفاتورة'
                          ? Colors.red.shade700
                          : Colors.green.shade700,
              padding:
                  const EdgeInsets.symmetric(
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

          // ======================================================
          // Cart
          // ======================================================

          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
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
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(
                      10,
                      8,
                      10,
                      170,
                    ),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 6),
                    itemBuilder: (_, i) =>
                        _CartRow(
                      item: cart[i],
                    ),
                  ),
          ),
        ],
      ),

      // ==========================================================
      // Bottom Checkout Area
      // ==========================================================

      bottomSheet: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            12,
            10,
            12,
            12,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surface,
            boxShadow: const [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black26,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Text(
                          'عدد القطع: $cartQuantity',
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                        const Text(
                          'الإجمالي',
                          style: TextStyle(
                            fontSize: 15,
                          ),
                        ),
                        PriceText(
                          total,
                          fontSize: 28,
                          weight: FontWeight.w900,
                        ),
                      ],
                    ),
                  ),

                  // إلغاء الفاتورة
                  IconButton(
                    tooltip: 'فاتورة جديدة',
                    onPressed: cart.isEmpty ||
                            isSavingInvoice
                        ? null
                        : newInvoice,
                    icon: const Icon(
                      Icons.refresh,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // إتمام البيع
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: cart.isEmpty ||
                          isSavingInvoice
                      ? null
                      : completeSale,
                  icon: isSavingInvoice
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.point_of_sale,
                        ),
                  label: Text(
                    isSavingInvoice
                        ? 'جاري حفظ الفاتورة...'
                        : 'إتمام البيع',
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

// ================================================================
// Cart Row
// ================================================================

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
      direction:
          DismissDirection.endToStart,

      background: Container(
        alignment: Alignment.centerRight,
        padding:
            const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),

      onDismissed: (_) {
        ref
            .read(cartProvider.notifier)
            .remove(
              item.product.barcode,
            );
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
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.bold,
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
                      .read(
                        cartProvider.notifier,
                      )
                      .decrement(
                        item.product.barcode,
                      );
                },
                icon: const Icon(
                  Icons
                      .remove_circle_outline,
                ),
              ),

              Text(
                '${item.quantity}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              IconButton(
                onPressed: () {
                  if (item.quantity >=
                      item.product.quantity) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'لا توجد كمية إضافية في المخزون',
                        ),
                      ),
                    );

                    return;
                  }

                  ref
                      .read(
                        cartProvider.notifier,
                      )
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
