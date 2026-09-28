import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  final TextEditingController _searchController =
      TextEditingController();

  List<Map<String, Object?>> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final invoices = await ref
          .read(databaseProvider)
          .getInvoices(
            query: _searchController.text.trim(),
          );

      if (!mounted) return;

      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'حدث خطأ أثناء تحميل الفواتير',
        isError: true,
      );
    }
  }

  Future<void> _showInvoiceDetails(
    Map<String, Object?> invoice,
  ) async {
    final invoiceId = (invoice['id'] as num?)?.toInt();

    if (invoiceId == null) return;

    try {
      final details = await ref
          .read(databaseProvider)
          .getInvoice(invoiceId);

      if (!mounted) return;

      if (details == null) {
        _showMessage(
          'الفاتورة غير موجودة',
          isError: true,
        );
        return;
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) {
          return _InvoiceDetailsSheet(
            invoice: details,
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'تعذر تحميل تفاصيل الفاتورة',
        isError: true,
      );
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

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(2)} ج.م';
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'الفواتير والمبيعات',
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _loadInvoices,
              tooltip: 'تحديث',
              icon: const Icon(
                Icons.refresh,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _loadInvoices(),
                decoration: InputDecoration(
                  hintText: 'ابحث برقم الفاتورة',
                  prefixIcon: const Icon(
                    Icons.search,
                  ),
                  suffixIcon:
                      _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _loadInvoices();
                                setState(() {});
                              },
                              icon: const Icon(
                                Icons.clear,
                              ),
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
                  : _invoices.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _loadInvoices,
                          child: ListView(
                            children: const [
                              SizedBox(height: 150),
                              Center(
                                child: Text(
                                  'لا توجد فواتير',
                                  style: TextStyle(
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadInvoices,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              12,
                              0,
                              12,
                              20,
                            ),
                            itemCount: _invoices.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final invoice =
                                  _invoices[index];

                              final invoiceNumber =
                                  (invoice['invoice_number']
                                          as num?)
                                      ?.toInt() ??
                                      0;

                              final total =
                                  (invoice['total'] as num?)
                                      ?.toDouble() ??
                                      0;

                              final createdAt =
                                  invoice['created_at']
                                          as String? ??
                                      '';

                              return Card(
                                child: ListTile(
                                  onTap: () =>
                                      _showInvoiceDetails(
                                    invoice,
                                  ),
                                  leading: const CircleAvatar(
                                    child: Icon(
                                      Icons.receipt_long,
                                    ),
                                  ),
                                  title: Text(
                                    'فاتورة #$invoiceNumber',
                                    style: const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize: 17,
                                    ),
                                  ),
                                  subtitle: createdAt.isEmpty
                                      ? null
                                      : Text(
                                          _formatDate(
                                            createdAt,
                                          ),
                                        ),
                                  trailing: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatMoney(total),
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const Text(
                                        'عرض التفاصيل',
                                        style: TextStyle(
                                          fontSize: 11,
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

class _InvoiceDetailsSheet extends StatelessWidget {
  final Map<String, Object?> invoice;

  const _InvoiceDetailsSheet({
    required this.invoice,
  });

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(2)} ج.م';
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

  @override
  Widget build(BuildContext context) {
    // =========================================================
    // FIX:
    // getInvoice() returns:
    //
    // {
    //   'invoice': invoices.first,
    //   'items': items,
    // }
    //
    // لذلك بيانات الفاتورة الأساسية موجودة داخل invoice['invoice']
    // =========================================================

    final invoiceData =
        (invoice['invoice'] as Map?)?.cast<String, Object?>() ??
            <String, Object?>{};

    final invoiceNumber =
        (invoiceData['invoice_number'] as num?)?.toInt() ?? 0;

    final total =
        (invoiceData['total'] as num?)?.toDouble() ?? 0;

    final createdAt =
        invoiceData['created_at'] as String? ?? '';

    final items =
        (invoice['items'] as List?)
                ?.cast<Map<String, Object?>>()
                .toList() ??
            [];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  12,
                ),
                child: Column(
                  children: [
                    Text(
                      'فاتورة #$invoiceNumber',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(
                height: 1,
              ),

              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد تفاصيل للفاتورة',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(),
                        itemBuilder: (context, index) {
                          final item = items[index];

                          final name =
                              item['product_name']
                                      as String? ??
                                  'منتج';

                          final price =
                              (item['price'] as num?)
                                      ?.toDouble() ??
                                  0;

                          final quantity =
                              (item['quantity'] as num?)
                                      ?.toDouble() ??
                                  0;

                          final lineTotal =
                              (item['line_total'] as num?)
                                      ?.toDouble() ??
                                  0;

                          return ListTile(
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${_formatQuantity(quantity)} × '
                              '${_formatMoney(price)}',
                            ),
                            trailing: Text(
                              _formatMoney(lineTotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // =================================================
              // INVOICE TOTAL
              // =================================================
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الإجمالي',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatMoney(total),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
