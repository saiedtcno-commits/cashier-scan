import 'package:flutter/material.dart';

String egp(double value) => '${value.toStringAsFixed(2)} ج.م';

class PriceText extends StatelessWidget {
  final double value;
  final double fontSize;
  final FontWeight weight;
  const PriceText(this.value, {super.key, this.fontSize = 16, this.weight = FontWeight.w700});

  @override
  Widget build(BuildContext context) => Text(
        egp(value),
        textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: fontSize, fontWeight: weight),
      );
}
