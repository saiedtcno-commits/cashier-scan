import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  bool _loading = false;

  Map<String, Object?>? _salesReport;
  List<Map<String, Object?>> _topProducts = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReport();
    });
  }

  Future<void> _loadReport() async {
    if (_fromDate.isAfter(_toDate)) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final db = ref.read(databaseProvider);

      final from = DateTime(
        _fromDate.year,
        _fromDate.month,
        _fromDate.day,
        0,
        0,
        0,
      );

      final to = DateTime(
        _toDate.year,
        _toDate.month,
        _toDate.day,
        23,
        59,
        59,
        999,
      );

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
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء تحميل التقرير: $e',
          ),
        ),
      );
    }
  }

  Future<void> _selectFromDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
      firstDate: _fromDate,
      lastDate: DateTime.now(),
    );

    if (selected == null) return;

    setState(() {
      _toDate = selected;
    });

    await _loadReport();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  double _toDouble(Object? value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  int _toInt(Object? value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  String _formatMoney(Object? value) {
    return '${_toDouble(value).toStringAsFixed(2)} جنيه';
  }

  @override
  Widget build(BuildContext context) {
    final invoiceCount = _toInt(
      _salesReport?['invoice_count'],
    );

    final totalSales = _toDouble(
      _salesReport?['total_sales'],
    );

    final itemCount = _toInt(
      _salesReport?['item_count'],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'التقارير',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadReport,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReport,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildDateFilter(),

              const SizedBox(height: 16),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                _buildSummaryCards(
                  invoiceCount: invoiceCount,
                  totalSales: totalSales,
                  itemCount: itemCount,
                ),

                const SizedBox(height: 24),

                _buildTopProducts(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.date_range,
                  color: Colors.purple,
                ),
                SizedBox(width: 8),
                Text(
                  'فترة التقرير',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                    title: 'من تاريخ',
                    date: _fromDate,
                    onTap: _selectFromDate,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _buildDateButton(
                    title: 'إلى تاريخ',
                    date: _toDate,
                    onTap: _selectToDate,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _loadReport,
                icon: const Icon(Icons.analytics),
                label: const Text(
                  'عرض التقرير',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateButton({
    required String title,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade400,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.calendar_month,
                  size: 20,
                  color: Colors.purple,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
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
    required int itemCount,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.receipt_long,
                title: 'الفواتير',
                value: invoiceCount.toString(),
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                icon: Icons.shopping_cart,
                title: 'المنتجات المباعة',
                value: itemCount.toString(),
                color: Colors.blue,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _summaryCard(
          icon: Icons.payments,
          title: 'إجمالي المبيعات',
          value: _formatMoney(totalSales),
          color: Colors.green,
          large: true,
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    bool large = false,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(large ? 20 : 16),
        child: Column(
          children: [
            CircleAvatar(
              radius: large ? 28 : 24,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                icon,
                size: large ? 30 : 26,
                color: color,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: large ? 15 : 13,
                color: Colors.grey.shade700,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: large ? 24 : 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProducts() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.trending_up,
                  color: Colors.purple,
                ),
                SizedBox(width: 8),
                Text(
                  'أكثر المنتجات مبيعاً',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_topProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'لا توجد مبيعات خلال هذه الفترة',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topProducts.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final product = _topProducts[index];

                  final productName =
                      product['product_name']?.toString() ??
                          'منتج غير معروف';

                  final quantity = _toDouble(
                    product['total_quantity'],
                  );

                  final sales = _toDouble(
                    product['total_sales'],
                  );

                  return ListTile(
                    contentPadding: EdgeInsets.zero,

                    leading: CircleAvatar(
                      backgroundColor:
                          Colors.purple.withValues(alpha: 0.12),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ),

                    title: Text(
                      productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    subtitle: Text(
                      'الكمية المباعة: ${quantity.toStringAsFixed(0)}',
                    ),

                    trailing: Text(
                      _formatMoney(sales),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
