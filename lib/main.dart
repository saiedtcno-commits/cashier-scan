import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/checkout_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: CashierScanApp()));
}

class CashierScanApp extends StatelessWidget {
  const CashierScanApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Cashier Scan',
    locale: const Locale('ar'),
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green, scaffoldBackgroundColor: const Color(0xFFF6F7F8), inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: const CheckoutScreen(),
  );
}
