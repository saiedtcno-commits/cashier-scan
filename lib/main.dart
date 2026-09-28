import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/checkout_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/reports_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    const ProviderScope(
      child: CashierScanApp(),
    ),
  );
}

class CashierScanApp extends StatelessWidget {
  const CashierScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cashier Scan',
      locale: const Locale('ar'),

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF6F7F8),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),

      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },

      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cashier Scan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              _HomeCard(
                icon: Icons.point_of_sale,
                title: 'الكاشير',
                subtitle: 'بيع المنتجات',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CheckoutScreen(),
                    ),
                  );
                },
              ),

              _HomeCard(
                icon: Icons.inventory_2,
                title: 'المخزون',
                subtitle: 'إدارة المخزون',
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InventoryScreen(),
                    ),
                  );
                },
              ),

              _HomeCard(
  icon: Icons.receipt_long,
  title: 'الفواتير',
  subtitle: 'المبيعات والفواتير',
  color: Colors.orange,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const InvoicesScreen(),
      ),
    );
  },
),

_HomeCard(
  icon: Icons.bar_chart,
  title: 'التقارير',
  subtitle: 'تقارير المبيعات',
  color: Colors.purple,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReportsScreen(),
      ),
    );
  },
),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
