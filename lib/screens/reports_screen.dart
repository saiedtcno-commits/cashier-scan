import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../providers/app_providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _fromDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  DateTime _toDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  Map<String, Object?>? _salesReport;
  List<Map<String, Object?>> _topProducts = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  String _startDateTime() {
    return DateTime(
      _fromDate.year,
      _fromDate.month,
      _fromDate.day,
      0,
      0,
      0,
    ).toIso8601String();
  }

  String _endDateTime() {
    return DateTime(
      _toDate.year,
      _toDate.month,
      _toDate.day,
      23,
      59,
      59,
      999,
    ).toIso8601String();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = ref.read(databaseProvider);

      final from = _startDateTime();
      final to = _endDateTime();

      final salesReport = await db.getSalesReport(
        from: from,
        to: to,
      );

      final topProducts = await db.getTopSellingProducts(
        from: from,
        to: to,
        limit: 10,
      );

      if (!mounted) return;

      setState(() {
        _salesReport = salesReport;
        _topProducts = topProducts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'حدث خطأ أثناء تحميل التقرير',
        isError: true,
      );
    }
  }

  Future<void> _selectFromDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );

    if (selected == null) return;

    setState(() {
      _fromDate = selected;

      if (_fromDate.isAfter(_toDate)) {
        _toDate = _fromDate;
      }
    });

    await _loadReport();
  }

  Future<void> _selectToDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );

    if (selected == null) return;

    if (selected.isBefore(_fromDate)) {
      _showMessage(
        'تاريخ النهاية لا يمكن أن يكون قبل تاريخ البداية',
        isError: true,
      );
      return;
    }

    setState(() {
      _toDate = selected;
    });

    await _loadReport();
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(2)} ج.م';
  }

  String _formatQuantity(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final invoiceCount =
        (_salesReport?['invoice_count'] as num?)?.toInt() ?? 0;

    final totalSales =
        (_salesReport?['total_sales'] as num?)?.toDouble() ?? 0;

    final itemCount =
        (_salesReport?['item_count'] as num?)?.toDouble() ?? 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('التقارير'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: _isLoading ? null : _loadReport,
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadReport,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDateFilter(),

                    const SizedBox(height: 16),

                    _buildSummaryCards(
                      invoiceCount: invoiceCount,
                      totalSales: totalSales,
                      itemCount: itemCount,
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'الأكثر مبيعًا',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    _buildTopProducts(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'فترة التقرير',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectFromDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Column(
                      children: [
                        const Text('من'),
                        Text(
                          _formatDate(_fromDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectToDate,
                    icon: const Icon(Icons.event),
                    label: Column(
                      children: [
                        const Text('إلى'),
                        Text(
                          _formatDate(_toDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards({
    required int invoiceCount,
    required double totalSales,
    required double itemCount,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.payments,
                title: 'إجمالي المبيعات',
                value: _formatMoney(totalSales),
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                icon: Icons.receipt_long,
                title: 'الفواتير',
                value: invoiceCount.toString(),
                color: Colors.orange,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        _SummaryCard(
          icon: Icons.shopping_cart,
          title: 'المنتجات المباعة',
          value: _formatQuantity(itemCount),
          color: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildTopProducts() {
    if (_topProducts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              Icon(
                Icons.bar_chart,
                size: 50,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'لا توجد مبيعات في الفترة المحددة',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topProducts.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = _topProducts[index];

          final name =
              product['product_name'] as String? ?? 'غير معروف';

          final barcode =
              product['barcode'] as String? ?? '';

          final quantity =
              (product['quantity'] as num?)?.toDouble() ?? 0;

          final total =
              (product['total_sales'] as num?)?.toDouble() ?? 0;

          return ListTile(
            leading: CircleAvatar(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              barcode.isEmpty
                  ? 'الكمية: ${_formatQuantity(quantity)}'
                  : '$barcode\nالكمية: ${_formatQuantity(quantity)}',
            ),
            isThreeLine: barcode.isNotEmpty,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatMoney(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_formatQuantity(quantity)} قطعة',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                icon,
                color: color,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
